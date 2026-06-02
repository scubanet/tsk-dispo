import SwiftUI
import AtollHub

/// Farb-Palette von ComHub (CoHub-Mockup). Akzent kommt aus dem
/// `AccentColor`-Asset (light/dark). Grautöne nutzen System-Semantik
/// (`.primary/.secondary/.tertiary`). Modul-Icons tragen je eine Toenung.
enum CoColor {
  static let accent = Color.accentColor

  static func module(_ module: ComHubModule) -> Color {
    switch module {
    case .heute:         return Color(red: 1.00, green: 0.62, blue: 0.04) // #FF9F0A
    case .kalender:      return Color(red: 1.00, green: 0.27, blue: 0.23) // #FF453A
    case .kombox:        return Color(red: 0.20, green: 0.78, blue: 0.35) // #34C759
    case .kontakte:      return Color(red: 0.56, green: 0.56, blue: 0.58) // #8E8E93
    case .tasks:         return Color(red: 1.00, green: 0.62, blue: 0.04) // #FF9F0A
    case .cardInbox:     return Color(red: 0.75, green: 0.35, blue: 0.95) // #BF5AF2
    case .einstellungen: return Color(red: 0.56, green: 0.56, blue: 0.58) // #8E8E93
    }
  }

  // window.AV palette from the CoHub mockup (spec section 1.5)
  static let avatar: [Color] = [
    Color(red: 1.00, green: 0.39, blue: 0.51), // #FF6482
    Color(red: 0.37, green: 0.61, blue: 1.00), // #5E9CFF
    Color(red: 1.00, green: 0.70, blue: 0.25), // #FFB340
    Color(red: 0.20, green: 0.78, blue: 0.35), // #34C759
    Color(red: 0.75, green: 0.35, blue: 0.95), // #BF5AF2
    Color(red: 1.00, green: 0.56, blue: 0.37), // #FF8E5E
    Color(red: 0.39, green: 0.82, blue: 1.00), // #64D2FF
    Color(red: 1.00, green: 0.27, blue: 0.23), // #FF453A
    Color(red: 0.67, green: 0.56, blue: 0.41), // #AC8E68
    Color(red: 0.19, green: 0.82, blue: 0.35), // #30D158
  ]

  static func avatarColor(for name: String) -> Color {
    avatar[AvatarPalette.index(for: name, count: avatar.count)]
  }
}
