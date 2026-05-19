import SwiftUI
import EventKit
import UniformTypeIdentifiers
import AtollCore
import AtollDesign

/// 7-day grid view: header row + all-day spans + hour grid via `TimeAxisGrid`.
///
/// Compact-column mode kicks in when each day column would be < 50pt wide
/// (iPhone SE landscape / split-view). In that mode:
/// - Weekday header uses `.caption2`, day-number `.subheadline`.
/// - EventBars render as colour-only stripes (no title text would fit).
struct WeekView: View {
  @Binding var anchor: Date
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

  @State private var eventsByDay: [Date: [CalendarEvent]] = [:]
  @State private var selectedEvent: CalendarEvent?
  @State private var editingEKEvent: IdentifiableEKEvent?
  @State private var scrolledHour: Int? = nil
  @State private var dropState = CalendarDropState()

  private let hourHeight: CGFloat = 60
  private let compactColumnThreshold: CGFloat = 50
  private let dragSnapMinutes: Int = 15

  private var weekSwipeGesture: some Gesture {
    DragGesture(minimumDistance: 50)
      .onEnded { value in
        let cal = Calendar.current
        if value.translation.width < -50 {
          anchor = cal.date(byAdding: .weekOfYear, value:  1, to: anchor) ?? anchor
        } else if value.translation.width > 50 {
          anchor = cal.date(byAdding: .weekOfYear, value: -1, to: anchor) ?? anchor
        }
      }
  }

  var body: some View {
    GeometryReader { geo in
      let days = daysOfWeek
      // Label area widens when the secondary-TZ column is enabled — keep the
      // day-column-width calculation in sync with TimeAxisGrid's layout.
      let labelArea = TimeAxisGrid<EmptyView>.totalLabelWidth(
        hourLabelWidth: TimeGridConstants.labelWidth,
        secondaryTimeZone: secondaryTimeZone
      )
      let columnWidth = max(0, (geo.size.width - labelArea - TimeGridConstants.gutter) / 7)
      let isCompact = columnWidth < compactColumnThreshold

      VStack(spacing: 0) {
        // Swipe-to-navigate is scoped to the header so it doesn't compete
        // with `.draggable` on event bars inside the grid.
        dayHeader(days: days, isCompact: isCompact, columnWidth: columnWidth, labelArea: labelArea)
          .gesture(weekSwipeGesture)

        allDayZone(days: days, columnWidth: columnWidth, labelArea: labelArea)

        TimeAxisGrid(hourHeight: hourHeight,
                     hourLabelWidth: TimeGridConstants.labelWidth,
                     secondaryTimeZone: secondaryTimeZone,
                     scrolledHour: $scrolledHour) {
          GlassEffectContainer(spacing: 4) {
            HStack(spacing: 0) {
              ForEach(days, id: \.self) { day in
                dayColumn(day: day, columnWidth: columnWidth, isCompact: isCompact)
                  .frame(width: columnWidth, alignment: .topLeading)
              }
            }
          }
        }
      }
    }
    .refreshable { await loadAll() }
    .task(id: anchor) {
      await loadAll()
      scrolledHour = preferredOpeningHour
    }
    .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in
      Task { await loadAll() }
    }
    .sheet(item: $selectedEvent) { EventDetailSheet(event: $0) }
    .sheet(item: $editingEKEvent) { wrapped in
      EventEditorSheet(editing: wrapped.event)
    }
  }

  // MARK: - Header row

  private func dayHeader(days: [Date], isCompact: Bool, columnWidth: CGFloat, labelArea: CGFloat) -> some View {
    HStack(spacing: 0) {
      Spacer().frame(width: labelArea + TimeGridConstants.gutter)
      ForEach(days, id: \.self) { day in
        VStack(spacing: 2) {
          Text(weekdayLabel(day))
            .font(isCompact ? .caption2 : .caption)
            .foregroundStyle(Calendar.current.isDateInToday(day) ? Color.accentColor : Color.secondary)
          Text("\(Calendar.current.component(.day, from: day))")
            .font(isCompact ? .subheadline : .headline)
            .foregroundStyle(dayNumberColor(day))
        }
        .frame(width: columnWidth)
      }
    }
    .padding(.vertical, 6)
    .background(.thinMaterial.opacity(0.6))
  }

  private func dayNumberColor(_ day: Date) -> Color {
    let cal = Calendar.current
    if cal.isDateInToday(day) { return .accentColor }
    let weekday = cal.component(.weekday, from: day)
    if weekday == 1 || weekday == 7 { return Color.secondary.opacity(0.7) }  // Sa/So dim
    return .primary
  }

  // MARK: - All-day zone (multi-day spans)

  @ViewBuilder
  private func allDayZone(days: [Date], columnWidth: CGFloat, labelArea: CGFloat) -> some View {
    let spans = allDaySpans(in: days)
    let lanes = (spans.map(\.lane).max() ?? -1) + 1
    let rowHeight: CGFloat = 18
    let zoneHeight = CGFloat(lanes) * rowHeight + (lanes > 0 ? 8 : 0)

    if !spans.isEmpty {
      ZStack(alignment: .topLeading) {
        Color.clear
        ForEach(spans) { span in
          let yOffset = CGFloat(span.lane) * rowHeight + 4
          let xOffset = CGFloat(span.startDayInWeek) * columnWidth + labelArea + TimeGridConstants.gutter + 2
          let width = max(0, CGFloat(span.lengthInWeek) * columnWidth - 4)

          HStack(spacing: 4) {
            Rectangle().fill(span.event.color).frame(width: 3, height: 12)
            Text(span.event.title).font(.caption2).lineLimit(1)
            Spacer(minLength: 0)
          }
          .padding(.horizontal, 4)
          .frame(width: width, height: rowHeight - 2, alignment: .leading)
          .background(span.event.color.opacity(0.15))
          .clipShape(.rect(cornerRadius: 3))
          .offset(x: xOffset, y: yOffset)
          .contentShape(Rectangle())
          .onTapGesture { selectedEvent = span.event }
          .contextMenu {
            AtollEventContextMenu(
              event: span.event,
              onView: { selectedEvent = span.event },
              onEdit: { ek in editingEKEvent = IdentifiableEKEvent(ek) },
              onDelete: { ek in try? calendarStore.remove(ek) },
              onOpenAtollWeb: {
                if let url = URL(string: "https://atoll.swiss") { openURL(url) }
              }
            )
          }
        }
      }
      .frame(height: zoneHeight)
      .background(.thinMaterial.opacity(0.5))
    }
  }

  // MARK: - Day column inside the time grid

  private func dayColumn(day: Date, columnWidth: CGFloat, isCompact: Bool) -> some View {
    let cal = Calendar.current
    let isToday = cal.isDateInToday(day)
    let dayStart = cal.startOfDay(for: day)
    let dayTimedEvents = (eventsByDay[dayStart] ?? []).filter { !$0.isAllDay }

    return ZStack(alignment: .topLeading) {
      // Today column tint — subtle, not Glass (would compete with EventBar glass)
      if isToday {
        Rectangle()
          .fill(Color.accentColor.opacity(0.05))
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      // Vertical separator
      Rectangle()
        .fill(Color.secondary.opacity(0.1))
        .frame(width: 0.5)
        .frame(maxHeight: .infinity)
        .offset(x: -0.25)

      ForEach(dayTimedEvents) { ev in
        eventLayout(for: ev, dayStart: dayStart, isCompact: isCompact)
      }
      if isToday {
        NowIndicator(hourHeight: hourHeight)
      }
      if let y = dropState.hoverY, dropState.activeDayStart == dayStart {
        dropTimeHint(at: y, dayStart: dayStart)
      }
    }
    .frame(width: columnWidth, alignment: .topLeading)
    .onDrop(of: [.atollSystemEvent], delegate: CalendarRescheduleDropDelegate(
      state: dropState,
      dayStart: dayStart,
      isPastDrop: { y in
        snappedDropDate(from: y, dayStart: dayStart) < Date()
      },
      onPerform: { payload, y in
        handleEventDrop(payload: payload, dayStart: dayStart, locationY: y)
      }
    ))
  }

  @ViewBuilder
  private func dropTimeHint(at hoverY: CGFloat, dayStart: Date) -> some View {
    let snapped = snappedDropMinutes(from: hoverY)
    let snappedY = CGFloat(snapped) / 60 * hourHeight
    let snappedDate = snappedDropDate(from: hoverY, dayStart: dayStart)
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
      Rectangle().fill(tint).frame(height: 1)
    }
    .offset(y: snappedY)
    .allowsHitTesting(false)
  }

  private func snappedDropMinutes(from hoverY: CGFloat) -> Int {
    let rawMin = max(0, Int((Double(hoverY) / Double(hourHeight)) * 60))
    return (rawMin / dragSnapMinutes) * dragSnapMinutes
  }

  private func snappedDropDate(from hoverY: CGFloat, dayStart: Date) -> Date {
    Calendar.current.date(byAdding: .minute, value: snappedDropMinutes(from: hoverY), to: dayStart) ?? dayStart
  }

  private static let hintTimeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "HH:mm"
    return f
  }()

  private func eventLayout(for ev: CalendarEvent, dayStart: Date, isCompact: Bool) -> some View {
    let cal = Calendar.current
    let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
    let evStart = max(ev.startDate, dayStart)
    let evEnd = min(ev.endDate, dayEnd)
    let startMinutes = evStart.timeIntervalSince(dayStart) / 60
    let durationMinutes = max(15, evEnd.timeIntervalSince(evStart) / 60)
    let yOffset = startMinutes / 60.0 * Double(hourHeight)
    let height = durationMinutes / 60.0 * Double(hourHeight)
    let style: EventBar.Style = isCompact ? .colorOnly : .auto

    let isPast = ev.endDate < Date()

    return EventBar(event: ev, measuredHeight: height, style: style, onTap: { selectedEvent = ev })
      .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
      .opacity(isPast ? 0.55 : 1.0)
      .draggableIfPossible(ev.dragPayload)
      .offset(y: yOffset)
      .padding(.horizontal, 2)
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

  // MARK: - Drop handler

  /// Snaps `locationY` (relative to the dropped-on day column, which spans the
  /// full 24h of `dayStart`) to a 15-min slot and reschedules the resolved
  /// EKEvent there. Duration is preserved.
  private func handleEventDrop(payload: SystemEventDragPayload, dayStart: Date, locationY: CGFloat) -> Bool {
    guard let ek = calendarStore.event(withIdentifier: payload.eventIdentifier) else { return false }
    let newStart = snappedDropDate(from: locationY, dayStart: dayStart)
    guard newStart >= Date() else { return false }
    do {
      try calendarStore.reschedule(ek, to: newStart, undoManager: undoManager)
      return true
    } catch {
      toastCenter.show("Termin verschieben fehlgeschlagen: \(error.localizedDescription)")
      return false
    }
  }

  // MARK: - Days of week / preferred opening hour

  /// Mo–So der Woche in der `anchor` liegt (ISO 8601 = Montag).
  private var daysOfWeek: [Date] {
    var cal = Calendar(identifier: .iso8601)
    cal.firstWeekday = 2
    let weekday = cal.component(.weekday, from: anchor)
    let daysFromMonday = (weekday + 5) % 7
    let monday = cal.date(byAdding: .day, value: -daysFromMonday, to: cal.startOfDay(for: anchor)) ?? anchor
    return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: monday) }
  }

  /// On mount / week change: if "today" falls inside this week, scroll to the
  /// live hour. Otherwise default to 08:00.
  private var preferredOpeningHour: Int {
    let cal = Calendar.current
    let days = daysOfWeek
    let today = Date()
    if let first = days.first, let last = days.last,
       cal.startOfDay(for: today) >= cal.startOfDay(for: first),
       cal.startOfDay(for: today) <= cal.startOfDay(for: last) {
      return cal.component(.hour, from: today)
    }
    return 8
  }

  private func weekdayLabel(_ d: Date) -> String {
    let f = DateFormatter()
    f.locale = locale
    f.dateFormat = "EE"
    return f.string(from: d)
  }

  // MARK: - All-day spans (greedy lane allocation)

  private struct AllDaySpan: Identifiable {
    let id: String
    let event: CalendarEvent
    let startDayInWeek: Int
    let lengthInWeek: Int
    var lane: Int = 0
  }

  private func allDaySpans(in days: [Date]) -> [AllDaySpan] {
    let cal = Calendar.current
    guard let weekStart = days.first.map({ cal.startOfDay(for: $0) }),
          let weekLast = days.last.map({ cal.startOfDay(for: $0) }) else { return [] }
    let weekEnd = cal.date(byAdding: .day, value: 1, to: weekLast) ?? weekLast

    var uniqueEvents: [CalendarEvent] = []
    var seenAtollAssignments = Set<UUID>()
    var seenSystemIds = Set<String>()

    for events in eventsByDay.values {
      for ev in events where ev.isAllDay {
        switch ev {
        case .atoll(let assignment, _, _):
          if !seenAtollAssignments.contains(assignment.id) {
            seenAtollAssignments.insert(assignment.id)
            uniqueEvents.append(ev)
          }
        case .system:
          if !seenSystemIds.contains(ev.id) {
            seenSystemIds.insert(ev.id)
            uniqueEvents.append(ev)
          }
        }
      }
    }

    struct RawSpan {
      let event: CalendarEvent
      let spanStart: Date
      let spanEnd: Date
    }

    var rawSpans: [RawSpan] = []
    for ev in uniqueEvents {
      let evStart: Date
      let evEnd: Date
      switch ev {
      case .atoll(let assignment, _, _):
        guard let course = assignment.course else { continue }
        let allDates = course.allDates
        guard let minDate = allDates.min(), let maxDate = allDates.max() else { continue }
        evStart = cal.startOfDay(for: minDate)
        evEnd = cal.startOfDay(for: maxDate)
      case .system(let ek):
        evStart = cal.startOfDay(for: ek.startDate)
        evEnd = cal.startOfDay(for: ek.endDate.addingTimeInterval(-1))
      }

      let spanStart = max(evStart, weekStart)
      let spanEndCapped = min(evEnd, cal.startOfDay(for: days.last ?? evEnd))
      guard spanStart <= spanEndCapped else { continue }
      guard spanStart < weekEnd && spanEndCapped >= weekStart else { continue }

      rawSpans.append(RawSpan(event: ev, spanStart: spanStart, spanEnd: spanEndCapped))
    }
    rawSpans.sort { $0.spanStart < $1.spanStart }

    var laneEndDates: [Date] = []
    var spans: [AllDaySpan] = []
    for raw in rawSpans {
      let startCol = cal.dateComponents([.day], from: weekStart, to: raw.spanStart).day ?? 0
      let length = (cal.dateComponents([.day], from: raw.spanStart, to: raw.spanEnd).day ?? 0) + 1

      var lane = 0
      while lane < laneEndDates.count {
        if raw.spanStart > laneEndDates[lane] {
          laneEndDates[lane] = raw.spanEnd
          break
        }
        lane += 1
      }
      if lane == laneEndDates.count {
        laneEndDates.append(raw.spanEnd)
      }
      spans.append(AllDaySpan(
        id: "\(raw.event.id)-\(startCol)-\(length)",
        event: raw.event,
        startDayInWeek: startCol,
        lengthInWeek: length,
        lane: lane
      ))
    }
    return spans
  }

  private func enabledCalendarIds() -> Set<String> {
    if let data = enabledCalendarIdsJSON.data(using: .utf8),
       let arr = try? JSONDecoder().decode([String].self, from: data) {
      return Set(arr)
    }
    return []
  }

  private func loadAll() async {
    let cal = Calendar.current
    let days = daysOfWeek
    guard let firstDay = days.first, let lastDay = days.last else { return }
    let weekStart = cal.startOfDay(for: firstDay)
    let weekEnd = cal.date(byAdding: .day, value: 1, to: lastDay) ?? lastDay
    let range = DateInterval(start: weekStart, end: weekEnd)

    var byDay: [Date: [CalendarEvent]] = [:]

    if sourceFilter.includesSystem {
      let sysIds = enabledCalendarIds()
      let sysEvents = calendarStore.events(in: range, calendarIds: sysIds.isEmpty ? nil : sysIds)
      for ek in sysEvents {
        let dayStart = cal.startOfDay(for: ek.startDate)
        byDay[dayStart, default: []].append(.system(ek))
      }
    }

    if sourceFilter.includesATOLL, atollEnabled, case .signedIn(let user) = auth.status {
      let instructorId = user.legacyInstructorId
      let extendedRange = DateInterval(
        start: cal.date(byAdding: .month, value: -1, to: weekStart) ?? weekStart,
        end:   cal.date(byAdding: .month, value: 1, to: weekEnd) ?? weekEnd
      )
      await atollLoader.reload(for: instructorId, range: extendedRange)
      // Expand per-module events for the week range, then bucket by start day.
      for assignment in atollLoader.assignments {
        for ev in CalendarEvent.expandATOLL(assignment, in: range) {
          let key = cal.startOfDay(for: ev.startDate)
          byDay[key, default: []].append(ev)
        }
      }
    }

    eventsByDay = byDay.mapValues { $0.sorted(by: { $0.startDate < $1.startDate }) }
  }
}

/// Shared layout constants so WeekView and TimeAxisGrid agree on the gutter.
private enum TimeGridConstants {
  static let labelWidth: CGFloat = 50
  static let gutter: CGFloat = 6
}
