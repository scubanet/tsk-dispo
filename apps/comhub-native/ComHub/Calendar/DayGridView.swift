import SwiftUI
import AtollHub

/// Zeitgitter über `days` (1 = Tag, 7 = Woche). Header-Zeile + Ganztags-Lane +
/// scrollbares Stundengitter mit positionierten Event-Blöcken + Now-Linie.
struct DayGridView: View {
  let store: CalendarStore
  let days: [Date]
  var onEventTap: ((UnifiedEvent) -> Void)? = nil

  /// Liefert den ungeschnittenen Original-Termin (volle Start/End-Zeiten) zur
  /// Block-Id — fuer das Bearbeiten uebernaechtiger Termine.
  private func original(of event: UnifiedEvent) -> UnifiedEvent {
    store.events.first { $0.id == event.id } ?? event
  }

  private let pxPerMin: CGFloat = 0.9

  /// Timed Events eines Tages, auf das Tagesfenster geclippt — uebernaechtige
  /// Termine erscheinen am Start- wie am Folgetag mit korrektem Anteil.
  private func timedEvents(_ day: Date) -> [UnifiedEvent] {
    let key = store.calendar.startOfDay(for: day)
    return (store.eventsByDay[key] ?? []).compactMap { ev -> UnifiedEvent? in
      guard !ev.isAllDay,
            let seg = DayClip.segment(event: ev, on: day, calendar: store.calendar)
      else { return nil }
      return ev.withTimes(start: seg.start, end: seg.end)
    }
  }

  private var allEvents: [UnifiedEvent] {
    days.flatMap { timedEvents($0) }
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
      Spacer().frame(width: 54)
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
    .fixedSize(horizontal: false, vertical: true)
  }

  private static let allDayRowHeight: CGFloat = 19
  private static let allDayRowGap: CGFloat = 3

  private func allDayColor(_ ev: UnifiedEvent) -> Color {
    ev.colorHex.flatMap(Color.init(hex:)) ?? (ev.source.type == .atoll ? CoColor.accent : .secondary)
  }

  /// Ganztags-Lane: durchgehende Balken (mehrtägige Events spannen über Spalten),
  /// kompakt — nur so hoch wie die belegten Reihen.
  @ViewBuilder
  private var allDayLane: some View {
    let rows = AllDaySpans.layout(store.events, days: days, calendar: store.calendar)
    if !rows.isEmpty {
      let laneHeight = CGFloat(rows.count) * Self.allDayRowHeight
        + CGFloat(max(rows.count - 1, 0)) * Self.allDayRowGap
      HStack(alignment: .top, spacing: 0) {
        Text("ganztägig").font(.system(size: 10)).foregroundStyle(.tertiary)
          .frame(width: 54, alignment: .trailing).padding(.trailing, 8)
        GeometryReader { proxy in
          let colW = proxy.size.width / CGFloat(max(days.count, 1))
          VStack(spacing: Self.allDayRowGap) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
              ZStack(alignment: .topLeading) {
                ForEach(row) { bar in
                  Button { onEventTap?(bar.event) } label: {
                    Text(bar.event.title).font(.system(size: 11, weight: .semibold))
                      .foregroundStyle(.white).lineLimit(1)
                      .padding(.horizontal, 7)
                      .frame(width: max(colW * CGFloat(bar.span) - 4, 0),
                             height: Self.allDayRowHeight, alignment: .leading)
                      .background(allDayColor(bar.event), in: RoundedRectangle(cornerRadius: 5))
                      .contentShape(Rectangle())
                  }
                  .buttonStyle(.plain)
                  // Positionierung ueber Leading-Padding (nicht .offset) — sonst liegt
                  // die Trefferflaeche ausserhalb der ZStack-Bounds (nicht klickbar).
                  .padding(.leading, colW * CGFloat(bar.startIndex) + 2)
                  .frame(maxWidth: .infinity, alignment: .leading)
                }
              }
              .frame(height: Self.allDayRowHeight, alignment: .leading)
              .frame(maxWidth: .infinity, alignment: .leading)
            }
          }
        }
        .frame(height: laneHeight)
      }
      .padding(.vertical, 5)
      .fixedSize(horizontal: false, vertical: true)
      Divider()
    }
  }

  private func dayColumn(_ day: Date) -> some View {
    let positioned = EventColumns.layout(timedEvents(day))
    return GeometryReader { proxy in
      ZStack(alignment: .topLeading) {
        ForEach(geo.startHour...geo.endHour, id: \.self) { h in
          Rectangle().fill(Color.primary.opacity(0.06)).frame(height: 1)
            .offset(y: CGFloat((h - geo.startHour) * 60) * geo.pxPerMin)
        }
        ForEach(positioned) { slot in
          let colW = proxy.size.width / CGFloat(slot.columnCount)
          EventBlockView(event: slot.event, onTap: { onEventTap?(original(of: slot.event)) })
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
