import SwiftUI

/// Initialen-Avatar in einer konsistenten Farbe basierend auf dem ID-Hash.
/// Zweck: Bessere Wiedererkennung in Teilnehmer-Listen und Skill-Chips.
struct StudentAvatar: View {
  let initials: String
  let id: UUID
  var size: CGFloat = 32

  var body: some View {
    Circle()
      .fill(backgroundColor)
      .frame(width: size, height: size)
      .overlay(
        Text(initials)
          .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
          .foregroundStyle(foregroundColor)
      )
  }

  /// Stabile Farbe pro UUID. Wir nehmen das erste Byte der UUID modulo Palette-Grösse.
  private var paletteIndex: Int {
    let firstByte = withUnsafeBytes(of: id.uuid) { $0.first ?? 0 }
    return Int(firstByte) % Self.palette.count
  }

  private var backgroundColor: Color { Self.palette[paletteIndex].background }
  private var foregroundColor: Color { Self.palette[paletteIndex].foreground }

  /// 8 Farb-Paare, hell genug für weisse Schrift bzw. dunkel genug für dunkle Schrift.
  /// Light-/dark-mode-tauglich über SwiftUI Color-Konstanten.
  private static let palette: [(background: Color, foreground: Color)] = [
    (Color(red: 0.62, green: 0.88, blue: 0.79), Color(red: 0.02, green: 0.20, blue: 0.17)), // teal
    (Color(red: 0.71, green: 0.83, blue: 0.96), Color(red: 0.02, green: 0.17, blue: 0.33)), // blue
    (Color(red: 0.96, green: 0.75, blue: 0.82), Color(red: 0.29, green: 0.08, blue: 0.16)), // pink
    (Color(red: 0.98, green: 0.78, blue: 0.46), Color(red: 0.26, green: 0.14, blue: 0.01)), // amber
    (Color(red: 0.81, green: 0.80, blue: 0.96), Color(red: 0.15, green: 0.13, blue: 0.36)), // purple
    (Color(red: 0.96, green: 0.77, blue: 0.70), Color(red: 0.29, green: 0.11, blue: 0.05)), // coral
    (Color(red: 0.75, green: 0.87, blue: 0.59), Color(red: 0.09, green: 0.20, blue: 0.04)), // green
    (Color(red: 0.83, green: 0.82, blue: 0.78), Color(red: 0.17, green: 0.17, blue: 0.16)), // gray
  ]
}
