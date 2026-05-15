import SwiftUI

/// Rote Linie mit Punkt für die aktuelle Zeit. Caller positioniert es nach
/// hourHeight-Maß (start-of-day origin) — wird automatisch alle 60 Sek refresht.
struct NowIndicator: View {
  let hourHeight: CGFloat

  @State private var now = Date()
  private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

  var body: some View {
    let cal = Calendar.current
    let hour = cal.component(.hour, from: now)
    let minute = cal.component(.minute, from: now)
    let yOffset = (Double(hour) + Double(minute) / 60.0) * Double(hourHeight)

    HStack(spacing: 0) {
      Circle()
        .fill(Color.red)
        .frame(width: 8, height: 8)
      Rectangle()
        .fill(Color.red)
        .frame(height: 1.5)
    }
    .offset(y: yOffset)
    .onReceive(timer) { now = $0 }
  }
}
