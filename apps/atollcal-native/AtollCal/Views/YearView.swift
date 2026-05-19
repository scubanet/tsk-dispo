import SwiftUI
import EventKit
import AtollCore

/// Full-year overview: 4 × 3 grid of compact month previews. Tap a month
/// title to jump there and switch to the month view.
///
/// Per-day event dots are loaded once for the visible year window.
struct YearView: View {
  @Binding var anchor: Date
  /// Called when the user taps a month title — jumps `focusedDate` to the
  /// first of that month and lets CalendarRoot switch to `.month`.
  let onSelectMonth: (Date) -> Void

  @Environment(SystemCalendarStore.self) private var calendarStore
  @Environment(AtollEventLoader.self) private var atollLoader
  @Environment(AuthState.self) private var auth

  @AppStorage("enabledCalendarIds") private var enabledCalendarIdsJSON: String = "[]"
  @AppStorage("atollEnabled") private var atollEnabled: Bool = true
  @AppStorage("calendarSourceFilter") private var sourceFilter: CalendarSourceFilter = .all

  @State private var eventCountByDay: [Date: Int] = [:]

  var body: some View {
    GeometryReader { geo in
      let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 4)
      ScrollView {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
          ForEach(yearMonths, id: \.self) { month in
            MonthPreview(
              month: month,
              eventCountByDay: eventCountByDay,
              compact: true,
              onTapTitle: { onSelectMonth(month) }
            )
          }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
      }
    }
    .gesture(
      DragGesture(minimumDistance: 50)
        .onEnded { value in
          let cal = Calendar.current
          if value.translation.width < -50 {
            anchor = cal.date(byAdding: .year, value:  1, to: anchor) ?? anchor
          } else if value.translation.width > 50 {
            anchor = cal.date(byAdding: .year, value: -1, to: anchor) ?? anchor
          }
        }
    )
    .task(id: anchor) { await loadCounts() }
    .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in
      Task { await loadCounts() }
    }
  }

  private var yearMonths: [Date] {
    let cal = Calendar.current
    let year = cal.component(.year, from: anchor)
    return (1...12).compactMap { month in
      cal.date(from: DateComponents(year: year, month: month, day: 1))
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
    let year = cal.component(.year, from: anchor)
    guard
      let rangeStart = cal.date(from: DateComponents(year: year, month: 1, day: 1)),
      let rangeEnd = cal.date(from: DateComponents(year: year + 1, month: 1, day: 1))
    else { return }
    let range = DateInterval(start: rangeStart, end: rangeEnd)

    if sourceFilter.includesATOLL, atollEnabled, case .signedIn(let user) = auth.status {
      await atollLoader.reload(for: user.legacyInstructorId, range: range)
    }

    var counts: [Date: Int] = [:]
    let sysIds = enabledCalendarIds()
    let sysEvents: [EKEvent] = sourceFilter.includesSystem
      ? calendarStore.events(in: range, calendarIds: sysIds.isEmpty ? nil : sysIds)
      : []
    for ek in sysEvents {
      let key = cal.startOfDay(for: ek.startDate)
      counts[key, default: 0] += 1
    }
    if sourceFilter.includesATOLL, atollEnabled {
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
