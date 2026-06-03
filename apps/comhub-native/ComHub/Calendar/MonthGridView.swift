import SwiftUI
import AtollHub

/// Monatsraster im CoHub-Look: 7 Spalten Mo–So, Tageszahlen (Heute markiert),
/// bis zu 4 Event-Farb-Dots je Tag. Tippen → Tag-Ansicht.
struct MonthGridView: View {
  let store: CalendarStore
  let onPickDay: (Date) -> Void

  private var weeks: [[Date]] { CalendarLayout.monthGrid(of: store.anchor, calendar: store.calendar) }
  private var anchorMonth: Int { store.calendar.component(.month, from: store.anchor) }
  private static let head = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 0) {
        ForEach(Self.head, id: \.self) { d in
          Text(d).font(.system(size: 11, weight: .semibold)).foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 6)
        }
      }
      .padding(.vertical, 8)

      VStack(spacing: 0) {
        ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
          HStack(spacing: 0) {
            ForEach(week, id: \.self) { day in
              cell(day); Divider()
            }
          }
          Divider()
        }
      }
      .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(CoTheme.separator, lineWidth: 1))
      .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    .padding(.horizontal, 16).padding(.bottom, 16)
  }

  @ViewBuilder
  private func cell(_ day: Date) -> some View {
    let dayStart = store.calendar.startOfDay(for: day)
    let inMonth = store.calendar.component(.month, from: day) == anchorMonth
    let isToday = store.calendar.isDate(day, inSameDayAs: Date())
    let events = store.eventsByDay[dayStart] ?? []
    let dotColors: [Color] = Array(
      events.compactMap { $0.colorHex.flatMap(Color.init(hex:)) ?? ($0.source.type == .atoll ? CoColor.accent : Color.secondary) }
        .reduce(into: [Color]()) { acc, c in if !acc.contains(c) { acc.append(c) } }
        .prefix(4)
    )

    VStack(alignment: .leading, spacing: 5) {
      Text("\(store.calendar.component(.day, from: day))")
        .font(.system(size: 12.5, weight: isToday ? .bold : .medium))
        .foregroundStyle(isToday ? AnyShapeStyle(.white) : (inMonth ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary)))
        .frame(width: 22, height: 22)
        .background(isToday ? CoColor.module(.kalender) : .clear, in: Circle())
      HStack(spacing: 3) {
        ForEach(Array(dotColors.enumerated()), id: \.offset) { _, c in
          Circle().fill(c).frame(width: 6, height: 6)
        }
      }
      Spacer(minLength: 0)
    }
    .padding(6)
    .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
    .background(inMonth ? Color.clear : Color.primary.opacity(0.03))
    .contentShape(Rectangle())
    .onTapGesture { onPickDay(day) }
  }
}
