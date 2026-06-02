import SwiftUI
import AtollHub

/// Wochenansicht: sieben Tagesspalten (Mo–So) mit ihren Events.
struct WeekGridView: View {
  let store: CalendarStore

  private static let header: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "EE dd.MM"
    f.locale = Locale(identifier: "de_CH")
    f.timeZone = TimeZone(identifier: "Europe/Zurich"); return f
  }()

  private var days: [Date] {
    CalendarLayout.weekDays(of: store.anchor, calendar: store.calendar)
  }

  var body: some View {
    ScrollView(.horizontal) {
      HStack(alignment: .top, spacing: 0) {
        ForEach(days, id: \.self) { day in
          VStack(alignment: .leading, spacing: 4) {
            Text(Self.header.string(from: day))
              .font(.caption.weight(.semibold))
              .frame(maxWidth: .infinity, alignment: .leading)
            Divider()
            let events = store.eventsByDay[store.calendar.startOfDay(for: day)] ?? []
            if events.isEmpty {
              Text("—").font(.caption2).foregroundStyle(.tertiary)
            } else {
              ForEach(events) { UnifiedEventRow(event: $0) }
            }
            Spacer(minLength: 0)
          }
          .padding(8)
          .frame(width: 200, alignment: .topLeading)
          Divider()
        }
      }
    }
  }
}
