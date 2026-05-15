import SwiftUI
import AtollCore
import AtollDesign

struct DayView: View {
  @Binding var date: Date
  @Environment(SystemCalendarStore.self) var calendarStore
  @Environment(AtollEventLoader.self) var atollLoader
  @Environment(AuthState.self) var auth
  @AppStorage("enabledCalendarIds") private var enabledCalendarIdsJSON: String = "[]"
  @AppStorage("atollEnabled") private var atollEnabled: Bool = true

  @State private var events: [CalendarEvent] = []
  @State private var selectedEvent: CalendarEvent?

  private let hourHeight: CGFloat = 60

  var body: some View {
    TimeAxisGrid(hourHeight: hourHeight) {
      ZStack(alignment: .topLeading) {
        // Event-Bars
        ForEach(events) { ev in
          eventLayout(for: ev)
        }
        // Now-Indikator nur wenn heute
        if Calendar.current.isDateInToday(date) {
          NowIndicator(hourHeight: hourHeight)
        }
      }
    }
    .refreshable { await loadAll() }
    .task(id: date) { await loadAll() }
    .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in
      Task { await loadAll() }
    }
    .sheet(item: $selectedEvent) { ev in
      EventDetailSheet(event: ev)
    }
  }

  private func eventLayout(for ev: CalendarEvent) -> some View {
    let cal = Calendar.current
    let dayStart = cal.startOfDay(for: date)
    let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
    let evStart = max(ev.startDate, dayStart)
    let evEnd = min(ev.endDate, dayEnd)
    let startMinutes = evStart.timeIntervalSince(dayStart) / 60
    let durationMinutes = max(15, evEnd.timeIntervalSince(evStart) / 60)
    let yOffset = startMinutes / 60.0 * Double(hourHeight)
    let height = durationMinutes / 60.0 * Double(hourHeight)

    return EventBar(event: ev, onTap: { selectedEvent = ev })
      .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
      .offset(y: yOffset)
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
    let dayStart = cal.startOfDay(for: date)
    let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
    let range = DateInterval(start: dayStart, end: dayEnd)

    var combined: [CalendarEvent] = []

    // System-Kalender
    let sysIds = enabledCalendarIds()
    let sysEvents = calendarStore.events(in: range, calendarIds: sysIds.isEmpty ? nil : sysIds)
    combined.append(contentsOf: sysEvents.map { .system($0) })

    // ATOLL — Range etwas weiter laden, damit Multi-Day-Kurse die in den Tag reinragen mit drin sind
    if atollEnabled, case .signedIn(let user) = auth.status {
      let instructorId = user.legacyInstructorId
      let extendedRange = DateInterval(
        start: cal.date(byAdding: .month, value: -1, to: range.start) ?? range.start,
        end:   cal.date(byAdding: .month, value: 1, to: range.end) ?? range.end
      )
      await atollLoader.reload(for: instructorId, range: extendedRange)
      // Filter: nur Assignments deren Course-allDates den heutigen Tag enthalten
      for assignment in atollLoader.assignments {
        guard let course = assignment.course else { continue }
        for d in course.allDates {
          if cal.isDate(d, inSameDayAs: date) {
            combined.append(.atoll(assignment: assignment, dayDate: d))
          }
        }
      }
    }

    events = combined.sorted(by: { $0.startDate < $1.startDate })
  }
}
