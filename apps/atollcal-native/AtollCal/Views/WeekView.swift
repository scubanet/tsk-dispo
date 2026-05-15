import SwiftUI
import AtollCore
import AtollDesign

struct WeekView: View {
  @Binding var anchor: Date
  @Environment(SystemCalendarStore.self) var calendarStore
  @Environment(AtollEventLoader.self) var atollLoader
  @Environment(AuthState.self) var auth
  @AppStorage("enabledCalendarIds") private var enabledCalendarIdsJSON: String = "[]"
  @AppStorage("atollEnabled") private var atollEnabled: Bool = true

  @State private var eventsByDay: [Date: [CalendarEvent]] = [:]

  private let hourHeight: CGFloat = 60
  private let hourLabelWidth: CGFloat = 50
  private let gutterWidth: CGFloat = 6

  var body: some View {
    GeometryReader { geo in
      let columnWidth = (geo.size.width - hourLabelWidth - gutterWidth) / 7
      let days = daysOfWeek

      VStack(spacing: 0) {
        // Day-Header-Zeile
        HStack(spacing: 0) {
          Spacer().frame(width: hourLabelWidth + gutterWidth)
          ForEach(days, id: \.self) { day in
            VStack(spacing: 2) {
              Text(weekdayLabel(day))
                .font(.caption)
                .foregroundColor(Calendar.current.isDateInToday(day) ? .accentColor : .secondary)
              Text("\(Calendar.current.component(.day, from: day))")
                .font(.headline)
                .foregroundColor(Calendar.current.isDateInToday(day) ? .accentColor : .primary)
            }
            .frame(width: columnWidth)
          }
        }
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.05))

        // Stunden-Grid + Spalten
        ScrollView {
          ZStack(alignment: .topLeading) {
            // Hour labels + horizontale Grid-Linien
            VStack(spacing: 0) {
              ForEach(0..<24, id: \.self) { hour in
                HStack(spacing: 0) {
                  Text(String(format: "%02d:00", hour))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(width: hourLabelWidth, alignment: .trailing)
                    .padding(.trailing, 6)
                    .padding(.top, -6)
                  Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 0.5)
                  Spacer(minLength: 0)
                }
                .frame(height: hourHeight, alignment: .top)
              }
            }

            // Day columns mit Events + Now-Indikator für heute
            HStack(spacing: 0) {
              Spacer().frame(width: hourLabelWidth + gutterWidth)
              ForEach(days, id: \.self) { day in
                ZStack(alignment: .topLeading) {
                  // Vertikale Trennlinie zwischen Spalten
                  Rectangle()
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 0.5)
                    .frame(maxHeight: .infinity)
                    .offset(x: -0.25)

                  ForEach(eventsByDay[Calendar.current.startOfDay(for: day)] ?? []) { ev in
                    eventLayout(for: ev, dayStart: Calendar.current.startOfDay(for: day))
                  }
                  if Calendar.current.isDateInToday(day) {
                    NowIndicator(hourHeight: hourHeight)
                  }
                }
                .frame(width: columnWidth, alignment: .topLeading)
              }
            }
          }
        }
      }
    }
    .gesture(
      DragGesture(minimumDistance: 50)
        .onEnded { value in
          if value.translation.width < -50 {
            anchor = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: anchor) ?? anchor
          } else if value.translation.width > 50 {
            anchor = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: anchor) ?? anchor
          }
        }
    )
    .refreshable { await loadAll() }
    .task(id: anchor) { await loadAll() }
    .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in
      Task { await loadAll() }
    }
  }

  /// Mo–So der Woche in der `anchor` liegt (ISO 8601 Wochenstart = Montag).
  private var daysOfWeek: [Date] {
    var cal = Calendar(identifier: .iso8601)
    cal.firstWeekday = 2  // Montag
    let weekday = cal.component(.weekday, from: anchor)
    let daysFromMonday = (weekday + 5) % 7  // Sun=1→6, Mon=2→0, Tue=3→1, ... , Sat=7→5
    let monday = cal.date(byAdding: .day, value: -daysFromMonday, to: cal.startOfDay(for: anchor)) ?? anchor
    return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: monday) }
  }

  private func weekdayLabel(_ d: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "de_CH")
    f.dateFormat = "EE"
    return f.string(from: d)
  }

  private func eventLayout(for ev: CalendarEvent, dayStart: Date) -> some View {
    let cal = Calendar.current
    let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
    let evStart = max(ev.startDate, dayStart)
    let evEnd = min(ev.endDate, dayEnd)
    let startMinutes = evStart.timeIntervalSince(dayStart) / 60
    let durationMinutes = max(15, evEnd.timeIntervalSince(evStart) / 60)
    let yOffset = startMinutes / 60.0 * Double(hourHeight)
    let height = durationMinutes / 60.0 * Double(hourHeight)

    return EventBar(event: ev, compact: true)
      .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
      .offset(y: yOffset)
      .padding(.horizontal, 2)
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

    // System-Kalender
    let sysIds = enabledCalendarIds()
    let sysEvents = calendarStore.events(in: range, calendarIds: sysIds.isEmpty ? nil : sysIds)
    for ek in sysEvents {
      let dayStart = cal.startOfDay(for: ek.startDate)
      byDay[dayStart, default: []].append(.system(ek))
    }

    // ATOLL — extended range damit Multi-Day-Kurse mitkommen
    if atollEnabled,
       case .signedIn(let user) = auth.status {
      let instructorId = user.legacyInstructorId
      let extendedRange = DateInterval(
        start: cal.date(byAdding: .month, value: -1, to: weekStart) ?? weekStart,
        end:   cal.date(byAdding: .month, value: 1, to: weekEnd) ?? weekEnd
      )
      await atollLoader.reload(for: instructorId, range: extendedRange)
      for assignment in atollLoader.assignments {
        guard let course = assignment.course else { continue }
        for d in course.allDates {
          let dayStart = cal.startOfDay(for: d)
          if dayStart >= weekStart && dayStart < weekEnd {
            byDay[dayStart, default: []].append(.atoll(assignment: assignment, dayDate: d))
          }
        }
      }
    }

    eventsByDay = byDay.mapValues { $0.sorted(by: { $0.startDate < $1.startDate }) }
  }
}
