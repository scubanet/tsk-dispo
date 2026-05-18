import SwiftUI
import AtollCore

/// Three months side-by-side: anchor − 1, anchor, anchor + 1. Tap a day to
/// jump the focused date (and let CalendarRoot switch to DayView).
///
/// Loads event counts for the visible 3-month window and feeds them to the
/// shared `MonthPreview` component for dot rendering.
struct QuarterView: View {
  @Binding var anchor: Date
  let onSelectDay: (Date) -> Void

  @Environment(SystemCalendarStore.self) private var calendarStore
  @Environment(AtollEventLoader.self) private var atollLoader
  @Environment(AuthState.self) private var auth

  @AppStorage("enabledCalendarIds") private var enabledCalendarIdsJSON: String = "[]"
  @AppStorage("atollEnabled") private var atollEnabled: Bool = true

  @State private var eventCountByDay: [Date: Int] = [:]

  var body: some View {
    HStack(alignment: .top, spacing: 20) {
      ForEach(quarterMonths, id: \.self) { month in
        MonthPreview(
          month: month,
          eventCountByDay: eventCountByDay,
          onTapDay: { day in onSelectDay(day) }
        )
        .frame(maxWidth: .infinity, alignment: .top)
      }
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 16)
    .gesture(
      DragGesture(minimumDistance: 50)
        .onEnded { value in
          let cal = Calendar.current
          if value.translation.width < -50 {
            anchor = cal.date(byAdding: .month, value:  3, to: anchor) ?? anchor
          } else if value.translation.width > 50 {
            anchor = cal.date(byAdding: .month, value: -3, to: anchor) ?? anchor
          }
        }
    )
    .task(id: anchor) { await loadCounts() }
    .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in
      Task { await loadCounts() }
    }
  }

  private var quarterMonths: [Date] {
    let cal = Calendar.current
    return [-1, 0, 1].compactMap {
      cal.date(byAdding: .month, value: $0, to: anchor)
    }
  }

  private func enabledCalendarIds() -> Set<String> {
    if let data = enabledCalendarIdsJSON.data(using: .utf8),
       let arr = try? JSONDecoder().decode([String].self, from: data) {
      return Set(arr)
    }
    return []
  }

  private func loadCounts() async {
    let cal = Calendar.current
    guard let firstMonth = quarterMonths.first,
          let lastMonth = quarterMonths.last,
          let rangeStart = cal.dateInterval(of: .month, for: firstMonth)?.start,
          let rangeEnd = cal.dateInterval(of: .month, for: lastMonth)?.end
    else { return }
    let range = DateInterval(start: rangeStart, end: rangeEnd)

    if atollEnabled, case .signedIn(let user) = auth.status {
      await atollLoader.reload(for: user.legacyInstructorId, range: range)
    }

    var counts: [Date: Int] = [:]
    let sysIds = enabledCalendarIds()
    let sysEvents = calendarStore.events(
      in: range,
      calendarIds: sysIds.isEmpty ? nil : sysIds
    )
    for ek in sysEvents {
      let key = cal.startOfDay(for: ek.startDate)
      counts[key, default: 0] += 1
    }
    if atollEnabled {
      for assignment in atollLoader.assignments {
        for ev in CalendarEvent.expandATOLL(assignment, in: range) {
          let key = cal.startOfDay(for: ev.startDate)
          counts[key, default: 0] += 1
        }
      }
    }
    eventCountByDay = counts
  }
}
