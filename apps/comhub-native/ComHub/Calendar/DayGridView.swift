import SwiftUI
import AtollHub

/// Zeitgitter über `days` (1 = Tag, 7 = Woche). Header-Zeile + Ganztags-Lane +
/// scrollbares Stundengitter mit positionierten Event-Blöcken + Now-Linie.
struct DayGridView: View {
  let store: CalendarStore
  let days: [Date]

  private let pxPerMin: CGFloat = 0.9

  private var allEvents: [UnifiedEvent] {
    days.flatMap { store.eventsByDay[store.calendar.startOfDay(for: $0)] ?? [] }
  }
  private var geo: CalendarGeometry {
    let w = DayWindow.hours(for: allEvents, calendar: store.calendar)
    return CalendarGeometry(startHour: w.startHour, endHour: w.endHour,
                            pxPerMin: pxPerMin, calendar: store.calendar)
  }

  private static let dayLabel: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "EE"
    f.locale = Locale(identifier: "de_CH")
    f.timeZone = TimeZone(identifier: "Europe/Zurich"); return f
  }()

  private func isToday(_ day: Date) -> Bool {
    store.calendar.isDate(day, inSameDayAs: Date())
  }

  var body: some View {
    VStack(spacing: 0) {
      headerRow
      Divider()
      allDayLane
      ScrollView {
        HStack(alignment: .top, spacing: 0) {
          TimeGutterView(geo: geo)
          ForEach(days, id: \.self) { day in
            dayColumn(day)
            Divider()
          }
        }
        .frame(height: geo.totalHeight)
        .padding(.vertical, 6)
      }
    }
  }

  private var headerRow: some View {
    HStack(spacing: 0) {
      Color.clear.frame(width: 54)
      ForEach(days, id: \.self) { day in
        HStack(alignment: .firstTextBaseline, spacing: 7) {
          Text(Self.dayLabel.string(from: day))
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(isToday(day) ? CoColor.module(.kalender) : .secondary)
          Text("\(store.calendar.component(.day, from: day))")
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(isToday(day) ? .white : .primary)
            .padding(.horizontal, isToday(day) ? 7 : 0).padding(.vertical, isToday(day) ? 3 : 0)
            .background(isToday(day) ? CoColor.module(.kalender) : .clear,
                        in: RoundedRectangle(cornerRadius: 8))
          Spacer(minLength: 0)
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        Divider()
      }
    }
  }

  @ViewBuilder
  private var allDayLane: some View {
    let lanes = days.map { day in
      (day, (store.eventsByDay[store.calendar.startOfDay(for: day)] ?? []).filter(\.isAllDay))
    }
    if lanes.contains(where: { !$0.1.isEmpty }) {
      HStack(spacing: 0) {
        Text("ganztägig").font(.system(size: 10)).foregroundStyle(.tertiary)
          .frame(width: 54, alignment: .trailing).padding(.trailing, 8)
        ForEach(lanes, id: \.0) { _, evs in
          VStack(alignment: .leading, spacing: 3) {
            ForEach(evs) { ev in
              Text(ev.title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                .lineLimit(1).padding(.horizontal, 7).padding(.vertical, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ev.source.type == .atoll ? CoColor.accent : Color.secondary,
                            in: RoundedRectangle(cornerRadius: 5))
            }
          }
          .padding(4).frame(maxWidth: .infinity, alignment: .leading)
          Divider()
        }
      }
      .padding(.vertical, 4)
      Divider()
    }
  }

  private func dayColumn(_ day: Date) -> some View {
    let dayKey = store.calendar.startOfDay(for: day)
    let positioned = EventColumns.layout(store.eventsByDay[dayKey] ?? [])
    return GeometryReader { proxy in
      ZStack(alignment: .topLeading) {
        ForEach(geo.startHour...geo.endHour, id: \.self) { h in
          Rectangle().fill(Color.primary.opacity(0.06)).frame(height: 1)
            .offset(y: CGFloat((h - geo.startHour) * 60) * geo.pxPerMin)
        }
        ForEach(positioned) { slot in
          let colW = proxy.size.width / CGFloat(slot.columnCount)
          EventBlockView(event: slot.event)
            .frame(width: colW - 3, height: geo.height(start: slot.event.start, end: slot.event.end))
            .offset(x: colW * CGFloat(slot.column) + 1, y: geo.y(slot.event.start))
        }
        if isToday(day) {
          let nowY = geo.y(Date())
          if nowY >= 0 && nowY <= geo.totalHeight {
            ZStack(alignment: .leading) {
              Rectangle().fill(CoColor.module(.kalender)).frame(height: 1.5)
              Circle().fill(CoColor.module(.kalender)).frame(width: 8, height: 8).offset(x: -4)
            }
            .offset(y: nowY)
          }
        }
      }
    }
    .frame(maxWidth: .infinity)
    .frame(height: geo.totalHeight)
  }
}
