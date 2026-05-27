import SwiftUI
import EventKit
import AtollCore
import AtollDesign

/// 6 × 7 grid month view with multi-day events as a lane-allocated overlay.
///
/// Lane logic: per week, multi-day events are greedily packed into stacked
/// "lanes". Each day cell reserves the top `lanesAbove × eventRowHeight`
/// space below the day-number, so single-day events render *below* the
/// multi-day bars instead of underneath them.
struct MonthView: View {
  @Binding var anchor: Date
  var onDayTap: (Date) -> Void = { _ in }

  @Environment(SystemCalendarStore.self) var calendarStore
  @Environment(AtollEventLoader.self) var atollLoader
  @Environment(AuthState.self) var auth
  @Environment(\.locale) var locale
  @AppStorage("enabledCalendarIds") private var enabledCalendarIdsJSON: String = "[]"
  @AppStorage("atollEnabled") private var atollEnabled: Bool = true
  @AppStorage("calendarSourceFilter") private var sourceFilter: CalendarSourceFilter = .all

  @Environment(\.openURL) private var openURL
  @Environment(\.undoManager) private var undoManager
  @Environment(ToastCenter.self) private var toastCenter

  @State private var eventsByDay: [Date: [CalendarEvent]] = [:]
  @State private var selectedEvent: CalendarEvent?
  @State private var editingEKEvent: IdentifiableEKEvent?

  /// All cell-internal sizes in one place so the multi-day overlay y-offset
  /// stays in sync with the day-number height.
  private enum CellMetrics {
    static let dayNumberHeight: CGFloat = 18
    static let eventRowHeight: CGFloat = 12
    static let moreRowHeight: CGFloat = 10
    static let cellPadding: CGFloat = 8
    static let maxEvents: Int = 3

    static var minCellHeight: CGFloat {
      dayNumberHeight + CGFloat(maxEvents) * eventRowHeight + moreRowHeight + cellPadding
    }
  }

  private var monthSwipeGesture: some Gesture {
    DragGesture(minimumDistance: 50)
      .onEnded { value in
        let cal = Calendar.current
        if value.translation.width < -50 {
          anchor = cal.date(byAdding: .month, value:  1, to: anchor) ?? anchor
        } else if value.translation.width > 50 {
          anchor = cal.date(byAdding: .month, value: -1, to: anchor) ?? anchor
        }
      }
  }

  var body: some View {
    VStack(spacing: 0) {
      // Swipe-to-navigate is scoped to the header so it doesn't compete with
      // `.draggable` on event rows inside the day cells.
      weekdayHeader
        .gesture(monthSwipeGesture)

      GeometryReader { geo in
        let cellWidth = geo.size.width / 7
        let weeks = monthWeeks
        let layout = computeMultiDayLayout(weeks: weeks)
        // Cell height: enough to hold all multi-day lanes + maxEvents single-day rows.
        // For weeks with many multi-day events we need a taller cell, otherwise the
        // grid floor applies (or the available height divided by week count).
        let neededHeight = CellMetrics.dayNumberHeight
          + CGFloat(layout.maxLanesAnywhere) * CellMetrics.eventRowHeight
          + CGFloat(CellMetrics.maxEvents) * CellMetrics.eventRowHeight
          + CellMetrics.moreRowHeight
          + CellMetrics.cellPadding
        let cellHeight = max(neededHeight, geo.size.height / CGFloat(weeks.count))

        ZStack(alignment: .topLeading) {
          VStack(spacing: 0) {
            ForEach(weeks.indices, id: \.self) { weekIdx in
              HStack(spacing: 0) {
                ForEach(weeks[weekIdx], id: \.self) { day in
                  dayCell(day, multiDayLanesAbove: layout.lanesPerWeek[weekIdx])
                    .frame(height: cellHeight)
                }
              }
            }
          }

          // Multi-day spans as overlay — each lane sits one eventRowHeight below
          // the day-number row.
          ForEach(layout.spans) { span in
            let yOffset = CGFloat(span.weekIndex) * cellHeight
              + CellMetrics.dayNumberHeight
              + CGFloat(span.lane) * CellMetrics.eventRowHeight
              + 1
            let xOffset = CGFloat(span.startDayInWeek) * cellWidth
            let width = max(0, CGFloat(span.lengthInWeek) * cellWidth - 4)

            HStack(spacing: 3) {
              Rectangle().fill(span.event.color).frame(width: 2)
              // GL-005 H2: Month grid is pixel-locked via CellMetrics
              // (eventRowHeight ~14 pt). `.minimumScaleFactor` lets the
              // Dynamic-Type system still scale within the bar bounds.
              Text(span.event.title)
                .font(.system(size: 9))
                .minimumScaleFactor(0.75)
                .lineLimit(1)
                .foregroundStyle(.primary)
              Spacer(minLength: 0)
            }
            .padding(.horizontal, 2)
            .frame(width: width, height: CellMetrics.eventRowHeight - 1)
            .background(span.event.color.opacity(0.22))
            .clipShape(.rect(cornerRadius: 2))
            .offset(x: xOffset + 2, y: yOffset)
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
      }
    }
    .task(id: anchor) { await loadAll() }
    .refreshable { await loadAll() }
    .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in
      Task { await loadAll() }
    }
    .sheet(item: $selectedEvent) { EventDetailSheet(event: $0) }
    .sheet(item: $editingEKEvent) { wrapped in
      EventEditorSheet(editing: wrapped.event)
    }
  }

  // MARK: - Weekday header

  private var weekdayHeader: some View {
    let labels = weekdayHeaderLabels
    return HStack(spacing: 0) {
      ForEach(Array(labels.enumerated()), id: \.offset) { idx, lbl in
        let isWeekend = idx >= 5
        Text(lbl)
          .font(.caption)
          .foregroundStyle(isWeekend ? Color.secondary.opacity(0.7) : Color.secondary)
          .frame(maxWidth: .infinity)
      }
    }
    .padding(.vertical, 6)
    // GL-005 M2: Intentionally a flat material band, not a glass card —
    // this is a full-width column-header strip (no rounded corners), same
    // pattern Apple uses for List/Table headers.
    .background(.thinMaterial.opacity(0.6))
  }

  private var weekdayHeaderLabels: [String] {
    let f = DateFormatter()
    f.locale = locale
    f.dateFormat = "EE"
    var cal = Calendar(identifier: .iso8601)
    cal.firstWeekday = 2
    guard let mondayReference = cal.date(from: DateComponents(year: 2026, month: 1, day: 5)) else {
      return ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
    }
    return (0..<7).compactMap { offset in
      cal.date(byAdding: .day, value: offset, to: mondayReference).map(f.string(from:))
    }
  }

  // MARK: - Day cell

  private func dayCell(_ day: Date, multiDayLanesAbove: Int) -> some View {
    let cal = Calendar.current
    let isCurrentMonth = cal.isDate(day, equalTo: anchor, toGranularity: .month)
    let isToday = cal.isDateInToday(day)
    let isPast = cal.startOfDay(for: day) < cal.startOfDay(for: Date())
    let weekday = cal.component(.weekday, from: day)
    let isWeekend = weekday == 1 || weekday == 7

    let allEvents = eventsByDay[cal.startOfDay(for: day)] ?? []
    let dayEvents = allEvents.filter { !isAllDayOrMultiDayEvent($0) }
    let maxRows = max(0, CellMetrics.maxEvents - multiDayLanesAbove)
    let visibleDayEvents = dayEvents.prefix(maxRows)
    let hiddenCount = dayEvents.count - visibleDayEvents.count

    return VStack(alignment: .leading, spacing: 1) {
      Text("\(cal.component(.day, from: day))")
        .font(.caption)
        .foregroundStyle(dayNumberColor(isToday: isToday, isCurrentMonth: isCurrentMonth, isWeekend: isWeekend))
        .padding(.horizontal, 4)
        .padding(.top, 4)
        .frame(height: CellMetrics.dayNumberHeight, alignment: .topLeading)

      // Reserve vertical space the multi-day overlay occupies in this week.
      if multiDayLanesAbove > 0 {
        Spacer()
          .frame(height: CGFloat(multiDayLanesAbove) * CellMetrics.eventRowHeight)
      }

      VStack(spacing: 1) {
        ForEach(visibleDayEvents) { ev in
          HStack(spacing: 3) {
            Rectangle()
              .fill(ev.color)
              .frame(width: 2, height: 10)
            // GL-005 H2: pixel-locked cell. See note above.
            Text(ev.title)
              .font(.system(size: 9))
              .minimumScaleFactor(0.75)
              .lineLimit(1)
              .foregroundStyle(isCurrentMonth ? .primary : .secondary)
          }
          .padding(.horizontal, 2)
          .frame(height: CellMetrics.eventRowHeight, alignment: .leading)
          .contentShape(Rectangle())
          .onTapGesture { selectedEvent = ev }
          .draggableIfPossible(ev.dragPayload())
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
        if hiddenCount > 0 {
          // GL-005 H2: pixel-locked cell. See note above.
          Text("+\(hiddenCount) weitere")
            .font(.system(size: 8))
            .minimumScaleFactor(0.75)
            .lineLimit(1)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 2)
            .frame(height: CellMetrics.moreRowHeight, alignment: .leading)
        }
      }

      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, minHeight: CellMetrics.minCellHeight, alignment: .topLeading)
    .background(isToday ? Color.accentColor.opacity(0.08) : Color.clear)
    .overlay(Rectangle().strokeBorder(Color.secondary.opacity(0.1), lineWidth: 0.5))
    .opacity(isPast && !isToday ? 0.65 : 1.0)
    .contentShape(Rectangle())
    .onTapGesture { onDayTap(day) }
    .dropDestination(for: SystemEventDragPayload.self) { items, _ in
      return handleEventDrop(items: items, droppedOn: day)
    }
  }

  /// Drop handler for MonthView. Moves the event to `day`, keeping its
  /// original wall-clock time-of-day. Duration is preserved by
  /// `SystemCalendarStore.reschedule(_:to:)`.
  private func handleEventDrop(items: [SystemEventDragPayload], droppedOn day: Date) -> Bool {
    guard let payload = items.first,
          let ek = calendarStore.event(withIdentifier: payload.eventIdentifier)
    else { return false }
    let cal = Calendar.current
    // Reject drops onto past days (today is allowed even if some hours are
    // already in the past — the time-of-day is preserved).
    guard cal.startOfDay(for: day) >= cal.startOfDay(for: Date()) else { return false }
    let timeComps = cal.dateComponents([.hour, .minute], from: ek.startDate)
    let dayStart = cal.startOfDay(for: day)
    let minuteOffset = (timeComps.hour ?? 0) * 60 + (timeComps.minute ?? 0)
    guard let newStart = cal.date(byAdding: .minute, value: minuteOffset, to: dayStart) else { return false }
    do {
      try calendarStore.reschedule(ek, to: newStart, undoManager: undoManager)
      return true
    } catch {
      toastCenter.show("Termin verschieben fehlgeschlagen: \(error.localizedDescription)")
      return false
    }
  }

  private func dayNumberColor(isToday: Bool, isCurrentMonth: Bool, isWeekend: Bool) -> Color {
    if isToday { return .accentColor }
    if !isCurrentMonth { return Color.secondary.opacity(0.5) }
    if isWeekend { return Color.secondary.opacity(0.7) }
    return .primary
  }

  // MARK: - Month-week computation

  private var monthWeeks: [[Date]] {
    var cal = Calendar(identifier: .iso8601)
    cal.firstWeekday = 2
    let comps = cal.dateComponents([.year, .month], from: anchor)
    guard let monthStart = cal.date(from: comps) else { return [] }
    let weekday = cal.component(.weekday, from: monthStart)
    let daysFromMonday = (weekday + 5) % 7
    guard let firstMonday = cal.date(byAdding: .day, value: -daysFromMonday, to: monthStart) else { return [] }
    return (0..<6).map { weekIdx in
      (0..<7).compactMap { dayIdx in
        cal.date(byAdding: .day, value: weekIdx * 7 + dayIdx, to: firstMonday)
      }
    }
  }

  // MARK: - Multi-day classification

  private func isMultiDayEvent(_ ev: CalendarEvent) -> Bool {
    let cal = Calendar.current
    let startDay = cal.startOfDay(for: ev.startDate)
    let endDay = cal.startOfDay(for: ev.endDate.addingTimeInterval(-1))
    return !cal.isDate(startDay, inSameDayAs: endDay)
  }

  private func isAllDayOrMultiDayEvent(_ ev: CalendarEvent) -> Bool {
    ev.isAllDay || isMultiDayEvent(ev)
  }

  // MARK: - Load

  private func enabledCalendarIds() -> Set<String> {
    if let data = enabledCalendarIdsJSON.data(using: .utf8),
       let arr = try? JSONDecoder().decode([String].self, from: data) {
      return Set(arr)
    }
    return []
  }

  private func loadAll() async {
    let cal = Calendar.current
    let weeks = monthWeeks
    guard let firstDay = weeks.first?.first, let lastDay = weeks.last?.last else { return }
    let rangeStart = cal.startOfDay(for: firstDay)
    let rangeEnd = cal.date(byAdding: .day, value: 1, to: lastDay) ?? lastDay
    let range = DateInterval(start: rangeStart, end: rangeEnd)

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
        start: cal.date(byAdding: .month, value: -1, to: rangeStart) ?? rangeStart,
        end:   cal.date(byAdding: .month, value: 1, to: rangeEnd) ?? rangeEnd
      )
      await atollLoader.reload(for: instructorId, range: extendedRange)
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

// MARK: - Multi-day layout (lane-allocated spans + per-week lane count)

private struct MultiDayEventSpan: Identifiable {
  let id: String
  let event: CalendarEvent
  let weekIndex: Int
  let startDayInWeek: Int
  let lengthInWeek: Int
  let lane: Int
}

private struct MultiDayLayout {
  let spans: [MultiDayEventSpan]
  let lanesPerWeek: [Int]
  let maxLanesAnywhere: Int
}

extension MonthView {
  fileprivate func computeMultiDayLayout(weeks: [[Date]]) -> MultiDayLayout {
    let cal = Calendar.current

    // 1. Collect distinct multi-day / all-day events that touch this month.
    var seen = Set<String>()
    var multiDayEvents: [CalendarEvent] = []
    for events in eventsByDay.values {
      for ev in events {
        guard isAllDayOrMultiDayEvent(ev) else { continue }
        if !seen.contains(ev.id) {
          seen.insert(ev.id)
          multiDayEvents.append(ev)
        }
      }
    }

    var allSpans: [MultiDayEventSpan] = []
    var lanesPerWeek: [Int] = Array(repeating: 0, count: weeks.count)

    // 2. Per-week lane allocation (greedy by start day).
    for (weekIdx, week) in weeks.enumerated() {
      guard let weekStartRaw = week.first, let weekLastRaw = week.last else { continue }
      let weekStart = cal.startOfDay(for: weekStartRaw)
      let weekLast = cal.startOfDay(for: weekLastRaw)

      struct WeekSpan {
        let event: CalendarEvent
        let startDay: Int
        let endDay: Int
      }

      var weekSpans: [WeekSpan] = []
      for ev in multiDayEvents {
        let evStart = cal.startOfDay(for: ev.startDate)
        let evEnd = cal.startOfDay(for: ev.endDate.addingTimeInterval(-1))

        let spanStart = max(evStart, weekStart)
        let spanEnd = min(evEnd, weekLast)
        guard spanStart <= spanEnd else { continue }

        let startDay = cal.dateComponents([.day], from: weekStart, to: spanStart).day ?? 0
        let endDay = cal.dateComponents([.day], from: weekStart, to: spanEnd).day ?? 0
        weekSpans.append(WeekSpan(event: ev, startDay: startDay, endDay: endDay))
      }

      weekSpans.sort { $0.startDay < $1.startDay }

      var laneLastEndDay: [Int] = []  // lane → last day index in use
      var maxLane = -1
      for span in weekSpans {
        var lane = 0
        while lane < laneLastEndDay.count {
          if span.startDay > laneLastEndDay[lane] {
            laneLastEndDay[lane] = span.endDay
            break
          }
          lane += 1
        }
        if lane == laneLastEndDay.count {
          laneLastEndDay.append(span.endDay)
        }
        maxLane = max(maxLane, lane)

        allSpans.append(MultiDayEventSpan(
          id: "\(span.event.id)-w\(weekIdx)",
          event: span.event,
          weekIndex: weekIdx,
          startDayInWeek: span.startDay,
          lengthInWeek: span.endDay - span.startDay + 1,
          lane: lane
        ))
      }

      lanesPerWeek[weekIdx] = (maxLane + 1)
    }

    return MultiDayLayout(
      spans: allSpans,
      lanesPerWeek: lanesPerWeek,
      maxLanesAnywhere: lanesPerWeek.max() ?? 0
    )
  }
}
