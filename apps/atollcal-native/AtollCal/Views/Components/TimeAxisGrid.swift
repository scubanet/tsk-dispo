import SwiftUI

/// Vertikale 24-Stunden-Achse mit Stunden-Labels links und horizontalen
/// Grid-Linien. Children werden als overlay positioniert — Caller berechnet
/// `y = stunde * hourHeight`.
///
/// Auto-scroll: jede Stunde bekommt eine `.id(hour)` (Integer 0–23).
/// `scrolledHour` ist eine Binding aus dem Caller — wird der Wert von außen
/// gesetzt (z. B. via `.task(id: date)`), scrollt die View die entsprechende
/// Stunde ans Anchor-Drittel von oben. Das nutzt die iOS-26-`scrollPosition`-API
/// ohne `ScrollViewReader`-Workaround.
///
/// Layout:
///
///   ┌───────────────────────────────┐
///   │ 00:00 ─────────────────────── │
///   │                               │
///   │ 01:00 ─────────────────────── │
///   │           [Event-Bar]         │
///   │ 02:00 ─────────────────────── │
///   │  ...                          │
struct TimeAxisGrid<Content: View>: View {
  let hourHeight: CGFloat
  let hourLabelWidth: CGFloat
  /// Stunde 0–23, die ans `anchor` (Default 1/3 von oben) gescrollt werden soll.
  /// `nil` = keine programmatische Scroll-Position erzwingen.
  @Binding var scrolledHour: Int?
  let scrollAnchor: UnitPoint
  @ViewBuilder let content: () -> Content

  init(hourHeight: CGFloat = 60,
       hourLabelWidth: CGFloat = 50,
       scrolledHour: Binding<Int?> = .constant(nil),
       scrollAnchor: UnitPoint = UnitPoint(x: 0.5, y: 0.33),
       @ViewBuilder content: @escaping () -> Content) {
    self.hourHeight = hourHeight
    self.hourLabelWidth = hourLabelWidth
    self._scrolledHour = scrolledHour
    self.scrollAnchor = scrollAnchor
    self.content = content
  }

  var body: some View {
    ScrollView {
      ZStack(alignment: .topLeading) {
        // Hour bands — each labelled and ID-tagged so scrollPosition can
        // target a specific hour. The full ZStack remains the content
        // ScrollView's child, so callers can compose events on top.
        VStack(spacing: 0) {
          ForEach(0..<24, id: \.self) { hour in
            hourBand(hour).id(hour)
          }
        }
        .scrollTargetLayout()

        // Caller content overlay — events + now-indicator. We push it right
        // past the hour-label gutter so layout matches the band positions.
        HStack(spacing: 0) {
          Spacer().frame(width: hourLabelWidth + 6)
          content()
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
      }
    }
    .scrollPosition(id: $scrolledHour, anchor: scrollAnchor)
  }

  private func hourBand(_ hour: Int) -> some View {
    HStack(alignment: .top, spacing: 0) {
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
}
