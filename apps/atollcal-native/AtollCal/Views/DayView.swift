import SwiftUI
import EventKit
import UniformTypeIdentifiers
import AtollCore
import AtollDesign

/// Single-day timeline with a separate all-day zone above the hour grid.
///
/// - All-day zone caps at 3 visible rows; a "+N weitere" button opens a sheet
///   listing every all-day event for the day.
/// - Hour grid uses `TimeAxisGrid` with the iOS 26 `scrollPosition(id:)` API
///   so we open with "now" anchored at ~1/3 from the top (or 08:00 on days
///   that aren't today).
struct DayView: View {
  @Binding var date: Date
  @Environment(SystemCalendarStore.self) var calendarStore
  @Environment(AtollEventLoader.self) var atollLoader
  @Environment(AuthState.self) var auth
  @Environment(\.locale) var locale

  @AppStorage("enabledCalendarIds") private var enabledCalendarIdsJSON: String = "[]"
  @AppStorage("atollEnabled") private var atollEnabled: Bool = true
  @AppStorage("calendarSourceFilter") private var sourceFilter: CalendarSourceFilter = .all
  @AppStorage("secondaryTimeZoneID") private var secondaryTimeZoneID: String = ""

  /// Resolved secondary timezone from the persisted identifier, or `nil`
  /// when none is configured.
  private var secondaryTimeZone: TimeZone? {
    guard !secondaryTimeZoneID.isEmpty else { return nil }
    return TimeZone(identifier: secondaryTimeZoneID)
  }

  @Environment(\.openURL) private var openURL
  @Environment(\.undoManager) private var undoManager
  @Environment(ToastCenter.self) private var toastCenter

  @State private var events: [CalendarEvent] = []
  @State private var selectedEvent: CalendarEvent?
  @State private var editingEKEvent: IdentifiableEKEvent?
  @State private var showingAllDaySheet: Bool = false
  @State private var scrolledHour: Int? = nil

  /// Active drag-to-create selection in the timed grid (y-coordinates in the
  /// `TimeAxisGrid`'s coordinate space). `nil` when no drag is in progress.
  @State private var dragSelection: DragSelection?

  /// Live drop state for drag-to-reschedule. Tracks cursor y and dragged
  /// event duration so the body can render a "where will this land" hint.
  @State private var dropState = CalendarDropState()

  /// Set when a drag-to-create finishes — triggers the EventEditorSheet via
  /// `.sheet(item:)`. Wrapper around DateInterval so it can be Identifiable.
  @State private var quickAddRange: QuickAddRange?

  // Drag-to-reschedule uses Transferable (`.draggable` + `.dropDestination`)
  // rather than `DragGesture` on the foreground events — DragGesture proved
  // unsolvable inside ScrollView → GeometryReader → ZStack on macOS 26. The
  // tradeoff is no live snap preview during the drag (we get the system drag
  // pellet); the drop snaps to the nearest 15-min slot on release. ATOLL
  // events are deliberately excluded from drag (see `CalendarEvent.isReschedulable`).

  private let hourHeight: CGFloat = 60
  private let maxAllDayVisible: Int = 3
  private let dragSnapMinutes: Int = 15
  private let dragMinDuration: Int = 30  // minutes — minimum slot length on quick-add

  var body: some View {
    VStack(spacing: 0) {
      allDayZone

      TimeAxisGrid(hourHeight: hourHeight,
                   secondaryTimeZone: secondaryTimeZone,
                   scrolledHour: $scrolledHour) {
        GeometryReader { geo in
          let layout = layoutTimedEvents(timedEvents)

          ZStack(alignment: .topLeading) {
            // Drag-to-create background: simple drag on empty space creates
            // a new event in that time range. Events sit ON TOP of this
            // layer; clicks on events go to EventBar's internal onTap.
            Color.clear
              .frame(maxWidth: .infinity, maxHeight: .infinity)
              .contentShape(Rectangle())
              .gesture(
                DragGesture(minimumDistance: 8)
                  .onChanged { value in
                    if dragSelection == nil {
                      dragSelection = DragSelection(
                        startY: value.startLocation.y,
                        currentY: value.location.y
                      )
                    } else {
                      dragSelection?.currentY = value.location.y
                    }
                  }
                  .onEnded { value in
                    guard let sel = dragSelection else { return }
                    let interval = dateInterval(
                      startY: min(sel.startY, sel.currentY),
                      endY:   max(sel.startY, sel.currentY)
                    )
                    quickAddRange = QuickAddRange(interval: interval)
                    dragSelection = nil
                  }
              )
              .onDrop(of: [.atollSystemEvent], delegate: CalendarRescheduleDropDelegate(
                state: dropState,
                dayStart: Calendar.current.startOfDay(for: date),
                isPastDrop: { y in
                  snappedDropDate(from: y, grabOffsetY: dropState.grabOffsetY) < Date()
                },
                onPerform: { payload, y in
                  handleEventDrop(payload: payload, locationY: y)
                }
              ))

            if let sel = dragSelection {
              let top = min(sel.startY, sel.currentY)
              let height = max(8, abs(sel.currentY - sel.startY))
              RoundedRectangle(cornerRadius: 6)
                .fill(Color.accentColor.opacity(0.22))
                .overlay(
                  RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.accentColor, lineWidth: 1)
                )
                .frame(height: height)
                .offset(y: top)
                .allowsHitTesting(false)
            }

            ForEach(timedEvents) { ev in
              eventLayout(
                for: ev,
                info: layout[ev.id] ?? EventLayoutInfo(lane: 0, totalLanes: 1),
                availableWidth: geo.size.width
              )
            }
            if Calendar.current.isDateInToday(date) {
              NowIndicator(hourHeight: hourHeight)
            }
            if let y = dropState.hoverY {
              dropTimeHint(at: y)
            }
          }
        }
        .frame(height: hourHeight * 24)
      }
    }
    .refreshable { await loadAll() }
    .task(id: date) {
      await loadAll()
      // Position scroll on every date change.
      scrolledHour = preferredOpeningHour
    }
    .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in
      Task { await loadAll() }
    }
    .sheet(item: $selectedEvent) { ev in
      EventDetailSheet(event: ev)
    }
    .sheet(item: $editingEKEvent) { wrapped in
      EventEditorSheet(editing: wrapped.event)
    }
    .sheet(item: $quickAddRange) { range in
      EventEditorSheet(initialInterval: range.interval)
    }
    .sheet(isPresented: $showingAllDaySheet) {
      AllDayListSheet(events: allDayEvents) { tapped in
        // Dismiss-then-present pattern. SwiftUI can't stack two .sheet
        // modifiers on the same View reliably, so we delay the second sheet.
        showingAllDaySheet = false
        Task { @MainActor in
          try? await Task.sleep(for: .milliseconds(350))
          selectedEvent = tapped
        }
      }
    }
  }

  // MARK: - All-day zone

  @ViewBuilder
  private var allDayZone: some View {
    if !allDayEvents.isEmpty {
      let visible = Array(allDayEvents.prefix(maxAllDayVisible))
      let hidden = allDayEvents.count - visible.count

      VStack(spacing: 2) {
        ForEach(visible) { ev in
          allDayRow(ev)
        }
        if hidden > 0 {
          Button {
            showingAllDaySheet = true
          } label: {
            Text("+\(hidden) weitere")
              .font(.caption2)
              .fontWeight(.medium)
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.horizontal, 8)
              .padding(.vertical, 2)
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 6)
      .frame(maxWidth: .infinity, alignment: .leading)
      // GL-005 M2: Liquid-Glass discipline — use the token instead of raw
      // `.thinMaterial`. `atollGlassCard` already applies the rounded shape.
      .atollGlassCard(cornerRadius: 8)
      .padding(.horizontal, 6)
      .padding(.top, 4)
    }
  }

  private func allDayRow(_ ev: CalendarEvent) -> some View {
    let cal = Calendar.current
    let isPast = cal.startOfDay(for: ev.endDate.addingTimeInterval(-1))
      < cal.startOfDay(for: Date())

    return HStack(spacing: 6) {
      Rectangle().fill(ev.color).frame(width: 3, height: 14)
      Text(ev.title).font(.caption).lineLimit(1)
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 2)
    .background(ev.color.opacity(0.15))
    .clipShape(.rect(cornerRadius: 4))
    .opacity(isPast ? 0.55 : 1.0)
    .contentShape(Rectangle())
    .onTapGesture { selectedEvent = ev }
    .contextMenu {
      AtollEventContextMenu(
        event: ev,
        onView: { selectedEvent = ev },
        onEdit: { ek in editingEKEvent = IdentifiableEKEvent(ek) },
        onDelete: { ek in try? calendarStore.remove(ek) },
        onOpenAtollWeb: {
          if let url = URL(string: "https://atoll.swiss") { openURL(url) }
        }
      )
    }
  }

  // MARK: - Timed event layout

  private func eventLayout(for ev: CalendarEvent,
                           info: EventLayoutInfo,
                           availableWidth: CGFloat) -> some View {
    let cal = Calendar.current
    let dayStart = cal.startOfDay(for: date)
    let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
    let evStart = max(ev.startDate, dayStart)
    let evEnd = min(ev.endDate, dayEnd)
    let startMinutes = evStart.timeIntervalSince(dayStart) / 60
    let durationMinutes = max(15, evEnd.timeIntervalSince(evStart) / 60)
    let yOffset = startMinutes / 60.0 * Double(hourHeight)
    let height = durationMinutes / 60.0 * Double(hourHeight)

    // Side-by-side layout for overlapping clusters. Single events get full
    // width (totalLanes = 1); a 2-event overlap each gets half; etc.
    let columnWidth = availableWidth / CGFloat(info.totalLanes)
    let xOffset = CGFloat(info.lane) * columnWidth
    let barWidth = max(0, columnWidth - 2)  // 2pt gap between adjacent columns

    let isPast = ev.endDate < Date()

    return EventBar(event: ev, measuredHeight: height, onTap: { selectedEvent = ev })
      .frame(width: barWidth, height: height, alignment: .topLeading)
      .opacity(isPast ? 0.55 : 1.0)
      .draggableIfPossible(ev.dragPayload())
      .offset(x: xOffset, y: yOffset)
      .contextMenu {
        AtollEventContextMenu(
          event: ev,
          onView: { selectedEvent = ev },
          onEdit: { ek in editingEKEvent = IdentifiableEKEvent(ek) },
          onDelete: { ek in try? calendarStore.remove(ek) },
          onOpenAtollWeb: {
            if let url = URL(string: "https://atoll.swiss") { openURL(url) }
          }
        )
      }
  }

  // MARK: - Helpers

  private var allDayEvents: [CalendarEvent] { events.filter { $0.isAllDay } }
  private var timedEvents: [CalendarEvent] { events.filter { !$0.isAllDay } }

  /// Hour to scroll to on mount / date change:
  /// - today  → current hour (live)
  /// - other  → 08:00 (sensible workday start)
  private var preferredOpeningHour: Int {
    let cal = Calendar.current
    if cal.isDateInToday(date) {
      return cal.component(.hour, from: Date())
    }
    return 8
  }

  private func enabledCalendarIds() -> Set<String> {
    if let data = enabledCalendarIdsJSON.data(using: .utf8),
       let arr = try? JSONDecoder().decode([String].self, from: data) {
      return Set(arr)
    }
    return []
  }

  /// Per-event positioning info: lane index inside its overlap cluster, and
  /// the cluster's total lane count. `lane=0, totalLanes=1` → full-width.
  fileprivate struct EventLayoutInfo {
    let lane: Int
    let totalLanes: Int
  }

  /// Greedy lane allocation for overlapping timed events. Two events overlap
  /// when their `[start, end)` intervals intersect. Events that don't overlap
  /// anybody get `totalLanes=1` (full width); a 2-event overlap each gets
  /// `totalLanes=2` (half width side-by-side); 3-event cluster → thirds; etc.
  ///
  /// Algorithm: sort by start (then end-desc for stability), assign the lowest
  /// free lane greedily. Then for each event, scan its direct overlaps to
  /// determine the cluster's effective lane count.
  private func layoutTimedEvents(_ events: [CalendarEvent]) -> [String: EventLayoutInfo] {
    let sorted = events.sorted { lhs, rhs in
      if lhs.startDate != rhs.startDate { return lhs.startDate < rhs.startDate }
      return lhs.endDate > rhs.endDate
    }

    // Step 1: greedy lane assignment.
    var laneEndTimes: [Date] = []
    var laneByID: [String: Int] = [:]
    for ev in sorted {
      var lane = 0
      while lane < laneEndTimes.count {
        if ev.startDate >= laneEndTimes[lane] { break }
        lane += 1
      }
      if lane < laneEndTimes.count {
        laneEndTimes[lane] = ev.endDate
      } else {
        laneEndTimes.append(ev.endDate)
      }
      laneByID[ev.id] = lane
    }

    // Step 2: per-event cluster width = max(lane among events overlapping me) + 1.
    var result: [String: EventLayoutInfo] = [:]
    for ev in sorted {
      var maxLane = laneByID[ev.id] ?? 0
      for other in sorted where other.id != ev.id {
        if ev.startDate < other.endDate && other.startDate < ev.endDate {
          maxLane = max(maxLane, laneByID[other.id] ?? 0)
        }
      }
      result[ev.id] = EventLayoutInfo(
        lane: laneByID[ev.id] ?? 0,
        totalLanes: maxLane + 1
      )
    }
    return result
  }

  /// Drop handler for system event drags. Snaps `locationY` to the nearest
  /// 15-min slot inside `date` and reschedules the event there, keeping its
  /// original duration. Returns true on success; false silently absorbs
  /// errors (event vanished, calendar read-only).
  /// Renders the live snap-position indicator during a drop. Shows where the
  /// event's TOP will land (= cursor y on macOS, where `.draggable`'s drag
  /// image is anchored at the grab point — grab the top of the event for the
  /// most predictable landing). Turns red when over a past time.
  @ViewBuilder
  private func dropTimeHint(at hoverY: CGFloat) -> some View {
    let adjustedY = hoverY - dropState.grabOffsetY
    let snapped = snappedDropMinutes(from: adjustedY)
    let snappedY = CGFloat(snapped) / 60 * hourHeight
    let cal = Calendar.current
    let dayStart = cal.startOfDay(for: date)
    let snappedDate = cal.date(byAdding: .minute, value: snapped, to: dayStart) ?? dayStart
    let isPast = snappedDate < Date()
    let tint: Color = isPast ? .red : .accentColor

    HStack(spacing: 4) {
      Text(Self.hintTimeFormatter.string(from: snappedDate))
        .font(.caption2)
        .fontWeight(.semibold)
        .foregroundStyle(.white)
        .padding(.horizontal, 5)
        .padding(.vertical, 1)
        .background(tint)
        .clipShape(.rect(cornerRadius: 3))
      Rectangle()
        .fill(tint)
        .frame(height: 1)
    }
    .offset(y: snappedY)
    .allowsHitTesting(false)
  }

  /// Snap a (grab-offset-adjusted) y to the 15-min minute offset from `dayStart`.
  private func snappedDropMinutes(from adjustedY: CGFloat) -> Int {
    let rawMin = max(0, Int((Double(adjustedY) / Double(hourHeight)) * 60))
    return (rawMin / dragSnapMinutes) * dragSnapMinutes
  }

  /// Snap a hover y into a Date — applies grab-offset compensation so the
  /// resulting date anchors at the event-top position, not at the cursor.
  private func snappedDropDate(from hoverY: CGFloat, grabOffsetY: CGFloat) -> Date {
    let cal = Calendar.current
    let dayStart = cal.startOfDay(for: date)
    let adjustedY = hoverY - grabOffsetY
    return cal.date(byAdding: .minute, value: snappedDropMinutes(from: adjustedY), to: dayStart) ?? dayStart
  }

  private static let hintTimeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "HH:mm"
    return f
  }()

  private func handleEventDrop(payload: SystemEventDragPayload, locationY: CGFloat) -> Bool {
    guard let ek = calendarStore.event(withIdentifier: payload.eventIdentifier) else { return false }
    let newStart = snappedDropDate(from: locationY, grabOffsetY: payload.grabOffsetY)
    // Reject drops into the past so a fat-fingered drag can't accidentally
    // backdate a meeting. The system also shows the .forbidden cursor over
    // these zones (see CalendarRescheduleDropDelegate.dropUpdated).
    guard newStart >= Date() else { return false }
    do {
      try calendarStore.reschedule(ek, to: newStart, undoManager: undoManager)
      return true
    } catch {
      toastCenter.show("Termin verschieben fehlgeschlagen: \(error.localizedDescription)")
      return false
    }
  }

  /// Convert a vertical y-range (in TimeAxisGrid coordinates) into a snapped
  /// `DateInterval` anchored to the current `date`. Minimum length enforced so
  /// a tiny drag still produces a usable slot.
  private func dateInterval(startY: CGFloat, endY: CGFloat) -> DateInterval {
    let cal = Calendar.current
    let dayStart = cal.startOfDay(for: date)
    let rawStartMin = max(0, Int((Double(startY) / Double(hourHeight)) * 60))
    let rawEndMin = max(rawStartMin + dragMinDuration, Int((Double(endY) / Double(hourHeight)) * 60))
    // Snap both edges to the nearest 15-min boundary.
    let snappedStart = (rawStartMin / dragSnapMinutes) * dragSnapMinutes
    let snappedEnd = max(
      snappedStart + dragMinDuration,
      ((rawEndMin + dragSnapMinutes - 1) / dragSnapMinutes) * dragSnapMinutes
    )
    let start = cal.date(byAdding: .minute, value: snappedStart, to: dayStart) ?? dayStart
    let end = cal.date(byAdding: .minute, value: snappedEnd, to: dayStart) ?? dayStart
    return DateInterval(start: start, end: end)
  }

  private func loadAll() async {
    let cal = Calendar.current
    let dayStart = cal.startOfDay(for: date)
    let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
    let range = DateInterval(start: dayStart, end: dayEnd)

    var combined: [CalendarEvent] = []

    if sourceFilter.includesSystem {
      let sysIds = enabledCalendarIds()
      let sysEvents = calendarStore.events(in: range, calendarIds: sysIds.isEmpty ? nil : sysIds)
      combined.append(contentsOf: sysEvents.map { .system($0) })
    }

    if sourceFilter.includesATOLL, atollEnabled, case .signedIn(let user) = auth.status {
      let instructorId = user.legacyInstructorId
      let extendedRange = DateInterval(
        start: cal.date(byAdding: .month, value: -1, to: range.start) ?? range.start,
        end:   cal.date(byAdding: .month, value: 1, to: range.end) ?? range.end
      )
      await atollLoader.reload(for: instructorId, range: extendedRange)
      // Single-day range so the helper filters per-module events down to today.
      let dayRange = range
      for assignment in atollLoader.assignments {
        combined.append(contentsOf: CalendarEvent.expandATOLL(assignment, in: dayRange))
      }
    }

    events = combined.sorted(by: { $0.startDate < $1.startDate })
  }
}

// MARK: - Drag-to-create helpers

/// In-flight drag selection in y-pixels of the TimeAxisGrid coordinate space.
fileprivate struct DragSelection: Equatable {
  var startY: CGFloat
  var currentY: CGFloat
}

/// Identifiable wrapper around `DateInterval` so it works with `.sheet(item:)`.
fileprivate struct QuickAddRange: Identifiable {
  let id = UUID()
  let interval: DateInterval
}

// MARK: - All-day list sheet

private struct AllDayListSheet: View {
  let events: [CalendarEvent]
  let onTap: (CalendarEvent) -> Void
  @Environment(\.dismiss) var dismiss

  var body: some View {
    NavigationStack {
      List(events) { ev in
        Button {
          onTap(ev)
        } label: {
          HStack(spacing: 8) {
            Rectangle().fill(ev.color).frame(width: 3, height: 18)
            VStack(alignment: .leading, spacing: 2) {
              Text(ev.title).foregroundStyle(.primary)
              if let loc = ev.location, !loc.isEmpty {
                Text(loc).font(.caption).foregroundStyle(.secondary)
              }
            }
            Spacer()
          }
        }
        .buttonStyle(.plain)
      }
      .navigationTitle("Ganztägige Termine")
      #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Fertig") { dismiss() }
        }
      }
    }
    .presentationDetents([.medium, .large])
  }
}
