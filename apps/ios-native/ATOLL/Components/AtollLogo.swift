import SwiftUI

/// Native SwiftUI-Variante des ATOLL-Logos.
/// Outer reef ring + inner lagoon (radial gradient) + center islet.
/// Auf einem blue→teal Verlauf, gerundetes Quadrat.
struct AtollLogo: View {
  var size: CGFloat = 32
  var bare: Bool = false

  var body: some View {
    ZStack {
      if !bare {
        RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
          .fill(
            LinearGradient(
              colors: [Color(red: 0.04, green: 0.52, blue: 1.0), Color(red: 0.19, green: 0.69, blue: 0.78)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
      }

      // Outer reef ring with subtle gap (passage)
      Circle()
        .trim(from: 0.05, to: 0.92)
        .stroke(.white.opacity(0.95), style: StrokeStyle(lineWidth: size * 0.05, lineCap: .round))
        .rotationEffect(.degrees(-90))
        .padding(size * 0.16)

      // Inner lagoon
      Circle()
        .fill(
          RadialGradient(
            colors: [.white.opacity(0.55), .white.opacity(0.15)],
            center: .center,
            startRadius: 0,
            endRadius: size * 0.16
          )
        )
        .padding(size * 0.34)

      // Center islet
      Circle()
        .fill(.white.opacity(0.95))
        .frame(width: size * 0.09, height: size * 0.09)
    }
    .frame(width: size, height: size)
  }
}

#Preview {
  HStack(spacing: 20) {
    AtollLogo(size: 32)
    AtollLogo(size: 64)
    AtollLogo(size: 128)
  }
  .padding()
  .background(Color.gray.opacity(0.1))
}
