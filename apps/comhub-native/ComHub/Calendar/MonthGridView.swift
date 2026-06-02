import SwiftUI
import AtollHub

/// Monatsansicht: Wochen × 7 Tage. Jede Zelle zeigt die Tageszahl und bis zu
/// drei Event-Titel (+ „n weitere").
struct MonthGridView: View {
  let store: CalendarStore

  private var weeks: [[Date]] {
    CalendarLayout.monthGrid(of: store.anchor, calendar: store.calendar)
  }
  private var anchorMonth: Int {
    store.calendar.component(.month, from: store.anchor)
  }

  var body: some View {
    VStack(spacing: 0) {
      ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
        HStack(spacing: 0) {
          ForEach(week, id: \.self) { day in
            cell(for: day)
            Divider()
          }
        }
        Divider()
      }
    }
  }

  @ViewBuilder
  private func cell(for day: Date) -> some View {
    let dayStart = store.calendar.startOfDay(for: day)
    let events = store.eventsByDay[dayStart] ?? []
    let inMonth = store.calendar.component(.month, from: day) == anchorMonth
    VStack(alignment: .leading, spacing: 2) {
      Text("\(store.calendar.component(.day, from: day))")
        .font(.caption.weight(.semibold))
        .foregroundStyle(inMonth ? .primary : .tertiary)
      ForEach(events.prefix(3)) { e in
        Text(e.title).font(.caption2).lineLimit(1)
          .foregroundStyle(e.source.type == .atoll ? Color.accentColor : .secondary)
      }
      if events.count > 3 {
        Text("+\(events.count - 3) weitere").font(.caption2).foregroundStyle(.tertiary)
      }
      Spacer(minLength: 0)
    }
    .padding(4)
    .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
  }
}
