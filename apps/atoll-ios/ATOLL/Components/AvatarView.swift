import SwiftUI

/// Runder Avatar mit Initialen, optional gefärbt.
struct AvatarView: View {
  let initials: String
  let color: String?  // hex string from DB, e.g. "#0A84FF"

  var body: some View {
    GeometryReader { geo in
      let size = min(geo.size.width, geo.size.height)
      Circle()
        .fill(.linearGradient(
          colors: gradient,
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        ))
        .overlay(
          Text(initials.uppercased())
            .font(.system(size: size * 0.42, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
        )
        .overlay(
          Circle()
            .stroke(.white.opacity(0.4), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
    }
    .aspectRatio(1, contentMode: .fit)
  }

  private var gradient: [Color] {
    let base = parseHex(color) ?? Color.accentColor
    return [base, base.opacity(0.78)]
  }

  private func parseHex(_ hex: String?) -> Color? {
    guard let hex, hex.hasPrefix("#") else { return nil }
    let hexString = String(hex.dropFirst())
    var rgb: UInt64 = 0
    Scanner(string: hexString).scanHexInt64(&rgb)
    let r = Double((rgb & 0xFF0000) >> 16) / 255.0
    let g = Double((rgb & 0x00FF00) >> 8) / 255.0
    let b = Double(rgb & 0x0000FF) / 255.0
    return Color(red: r, green: g, blue: b)
  }
}
