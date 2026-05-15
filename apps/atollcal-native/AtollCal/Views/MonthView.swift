import SwiftUI
import AtollCore
import AtollDesign

struct MonthView: View {
  @Binding var anchor: Date
  /// Optional callback wenn der User einen Tag antippt — Caller (CalendarRoot)
  /// kann auf DayView dieses Tages umschalten.
  var onDayTap: (Date) -> Void = { _ in }

  @Environment(SystemCalendarStore.self) var calendarStore
  @Environment(AtollEventLoader.self) var atollLoader
  @Environment(AuthState.self) var auth
  @AppStorage("enabledCalendarIds") private var enabledCalendarIdsJSON: String = "[]"
  @AppStorage("atollEnabled") private var atollEnabled: Bool = true

  @State private var eventsByDay: [Date: [CalendarEvent]] = [:]

  var body: some View {
    VStack(spacing: 0) {
      // Wochentag-Header
      HStack(spacing: 0) {
        ForEach(["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"], id: \.self) { lbl in
          Text(lbl)
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
        }
      }
      .padding(.vertical, 6)
      .background(Color.secondary.opacity(0.05))

      // 6×7-Grid
      let weeks = monthWeeks
      VStack(spacing: 0) {
        ForEach(weeks.indices, id: \.self) { weekIdx in
          HStack(spacing: 0) {
            ForEach(weeks[weekIdx], id: \.self) { day in
              dayCell(day)
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
    .gesture(
      DragGesture(minimumDistance: 50)
        .onEnded { value in
          if value.translation.width < -50 {
            anchor = Calendar.current.date(byAdding: .month, value: 1, to: anchor) ?? anchor
          } else if value.translation.width > 50 {
            anchor = Calendar.current.date(byAdding: .month, value: -1, to: anchor) ?? anchor
          }
        }
    )
  }

  /// 6 Wochen × 7 Tage, beginnend am Montag der Woche die den 1. des Monats enthält.
  private var monthWeeks: [[Date]] {
    var cal = Calendar(identifier: .iso8601)
    cal.firstWeekday = 2  // Montag
    let comps = cal.dateComponents([.year, .month], from: anchor)
    guard let monthStart = cal.date(from: comps) else { return [] }
    let weekday = cal.component(.weekday, from: monthStart)  // Sun=1, Mon=2, ...
    let daysFromMonday = (weekday + 5) % 7
    guard let firstMonday = cal.date(byAdding: .day, value: -daysFromMonday, to: monthStart) else { return [] }
    return (0..<6).map { weekIdx in
      (0..<7).compactMap { dayIdx in
        cal.date(byAdding: .day, value: weekIdx * 7 + dayIdx, to: firstMonday)
      }
    }
  }

  private func dayCell(_ day: Date) -> some View {
    let cal = Calendar.current
    let isCurrentMonth = cal.isDate(day, equalTo: anchor, toGranularity: .month)
    let isToday = cal.isDateInToday(day)
    let dayEvents = eventsByDay[cal.startOfDay(for: day)] ?? []

    return VStack(alignment: .leading, spacing: 2) {
      Text("\(cal.component(.day, from: day))")
        .font(.caption)
        .foregroundColor(isToday ? .accentColor : (isCurrentMonth ? .primary : .secondary.opacity(0.5)))
        .padding(.horizontal, 4)
        .padding(.top, 4)

      VStack(spacing: 1) {
        ForEach(dayEvents.prefix(3)) { ev in
          HStack(spacing: 3) {
            Rectangle()
              .fill(ev.color)
              .frame(width: 2, height: 10)
            Text(ev.title)
              .font(.system(size: 9))
              .lineLimit(1)
              .foregroundColor(isCurrentMonth ? .primary : .secondary)
          }
          .padding(.horizontal, 2)
        }
        if dayEvents.count > 3 {
          Text("+\(dayEvents.count - 3) more")
            .font(.system(size: 8))
            .foregroundColor(.secondary)
            .padding(.horizontal, 2)
        }
      }

      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, minHeight: 70, alignment: .topLeading)
    .background(isToday ? Color.accentColor.opacity(0.1) : Color.clear)
    .border(Color.secondary.opacity(0.1), width: 0.5)
    .contentShape(Rectangle())  // ganze Cell tap-bar machen, nicht nur Text
    .onTapGesture { onDayTap(day) }
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
    let weeks = monthWeeks
    guard let firstDay = weeks.first?.first, let lastDay = weeks.last?.last else { return }
    let rangeStart = cal.startOfDay(for: firstDay)
    let rangeEnd = cal.date(byAdding: .day, value: 1, to: lastDay) ?? lastDay
    let range = DateInterval(start: rangeStart, end: rangeEnd)

    var byDay: [Date: [CalendarEvent]] = [:]

    let sysIds = enabledCalendarIds()
    let sysEvents = calendarStore.events(in: range, calendarIds: sysIds.isEmpty ? nil : sysIds)
    for ek in sysEvents {
      let dayStart = cal.startOfDay(for: ek.startDate)
      byDay[dayStart, default: []].append(.system(ek))
    }

    if atollEnabled,
       case .signedIn(let user) = auth.status {
      let instructorId = user.legacyInstructorId
      let extendedRange = DateInterval(
        start: cal.date(byAdding: .month, value: -1, to: rangeStart) ?? rangeStart,
        end:   cal.date(byAdding: .month, value: 1, to: rangeEnd) ?? rangeEnd
      )
      await atollLoader.reload(for: instructorId, range: extendedRange)
      for assignment in atollLoader.assignments {
        guard let course = assignment.course else { continue }
        for d in course.allDates {
          let dayStart = cal.startOfDay(for: d)
          if dayStart >= rangeStart && dayStart < rangeEnd {
            byDay[dayStart, default: []].append(.atoll(assignment: assignment, dayDate: d))
          }
        }
      }
    }

    eventsByDay = byDay.mapValues { $0.sorted(by: { $0.startDate < $1.startDate }) }
  }
}
