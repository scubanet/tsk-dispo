import SwiftUI

/// Linke Stunden-Beschriftung, ausgerichtet aufs Gitter.
struct TimeGutterView: View {
  let geo: CalendarGeometry

  var body: some View {
    ZStack(alignment: .topLeading) {
      ForEach(geo.startHour...geo.endHour, id: \.self) { h in
        Text(String(format: "%02d:00", h))
          .font(.system(size: 10.5, weight: .medium)).foregroundStyle(.tertiary)
          .frame(width: 46, alignment: .trailing)
          .offset(x: 0, y: CGFloat((h - geo.startHour) * 60) * geo.pxPerMin - 6)
      }
    }
    .frame(width: 54, height: geo.totalHeight, alignment: .topLeading)
  }
}
