import SwiftUI

/// Vertikale 24-Stunden-Achse mit Stunden-Labels links und horizontalen
/// Grid-Linien. Children werden als overlay positioniert — Caller berechnet
/// `y = stunde * hourHeight`.
///
/// Optional zweite Zeitzone: wenn `secondaryTimeZone` gesetzt, wird eine
/// dünnere Spalte links der primären Stunden-Labels gerendert mit der
/// entsprechenden Uhrzeit in dieser TZ. Praktisch für Reisen — zeigt z.B.
/// PHT-Zeit neben CET-Zeit für IE-Trips in die Philippinen.
///
/// Auto-scroll: jede Stunde bekommt eine `.id(hour)` (Integer 0–23).
/// `scrolledHour` ist eine Binding aus dem Caller — wird der Wert von außen
/// gesetzt (z. B. via `.task(id: date)`), scrollt die View die entsprechende
/// Stunde ans Anchor-Drittel von oben.
///
/// Layout:
///
///   ┌────────────────────────────────────────┐
///   │ [SecTZ] 00:00 ─────────────────────── │
///   │                                        │
///   │ [SecTZ] 01:00 ─────────────────────── │
///   │                  [Event-Bar]           │
///   │ [SecTZ] 02:00 ─────────────────────── │
///   │  ...                                   │
struct TimeAxisGrid<Content: View>: View {
  let hourHeight: CGFloat
  let hourLabelWidth: CGFloat
  let secondaryTimeZone: TimeZone?
  /// Stunde 0–23, die ans `anchor` (Default 1/3 von oben) gescrollt werden soll.
  @Binding var scrolledHour: Int?
  let scrollAnchor: UnitPoint
  @ViewBuilder let content: () -> Content

  init(hourHeight: CGFloat = 60,
       hourLabelWidth: CGFloat = 50,
       secondaryTimeZone: TimeZone? = nil,
       scrolledHour: Binding<Int?> = .constant(nil),
       scrollAnchor: UnitPoint = UnitPoint(x: 0.5, y: 0.33),
       @ViewBuilder content: @escaping () -> Content) {
    self.hourHeight = hourHeight
    self.hourLabelWidth = hourLabelWidth
    self.secondaryTimeZone = secondaryTimeZone
    self._scrolledHour = scrolledHour
    self.scrollAnchor = scrollAnchor
    self.content = content
  }

  /// Total width occupied by the hour-label area on the left.
  /// Used by callers (WeekView) that need to compute remaining day-column width.
  static func totalLabelWidth(hourLabelWidth: CGFloat = 50,
                              secondaryTimeZone: TimeZone?) -> CGFloat {
    secondaryTimeZone != nil ? (hourLabelWidth * 2 + 8) : hourLabelWidth
  }

  private var totalLabelWidth: CGFloat {
    Self.totalLabelWidth(hourLabelWidth: hourLabelWidth,
                         secondaryTimeZone: secondaryTimeZone)
  }

  var body: some View {
    ScrollView {
      ZStack(alignment: .topLeading) {
        VStack(spacing: 0) {
          ForEach(0..<24, id: \.self) { hour in
            hourBand(hour).id(hour)
          }
        }
        .scrollTargetLayout()

        HStack(spacing: 0) {
          Spacer().frame(width: totalLabelWidth + 6)
          content()
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
      }
    }
    .scrollPosition(id: $scrolledHour, anchor: scrollAnchor)
  }

  private func hourBand(_ hour: Int) -> some View {
    HStack(alignment: .top, spacing: 0) {
      if let tz = secondaryTimeZone {
        // GL-005 H2: Match the primary hour label (.caption2) for Dynamic-Type
        // consistency. Both labels share the same `hourLabelWidth` frame.
        Text(secondaryHourString(for: hour, in: tz))
          .font(.caption2)
          .foregroundStyle(.tertiary)
          .frame(width: hourLabelWidth, alignment: .trailing)
          .padding(.trailing, 4)
          .padding(.top, -6)
      }
      Text(String(format: "%02d:00", hour))
        .font(.caption2)
        .foregroundStyle(.secondary)
        .frame(width: hourLabelWidth, alignment: .trailing)
        .padding(.trailing, 6)
        .padding(.top, -6)
      Rectangle()
        .fill(Color.secondary.opacity(0.2))
        .frame(height: 0.5)
        .padding(.top, 0)
      Spacer(minLength: 0)
    }
    .frame(height: hourHeight, alignment: .top)
  }

  /// Time in the secondary TZ that corresponds to "today, hour:00 local".
  /// Returns "HH:mm" formatted string — handles DST correctly because the
  /// produced Date is fully timezone-anchored before being re-formatted.
  private func secondaryHourString(for hour: Int, in tz: TimeZone) -> String {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone.current
    let today = cal.startOfDay(for: Date())
    guard let primaryDate = cal.date(bySettingHour: hour, minute: 0, second: 0, of: today) else {
      return ""
    }
    let f = DateFormatter()
    f.timeZone = tz
    f.dateFormat = "HH:mm"
    return f.string(from: primaryDate)
  }
}
