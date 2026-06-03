import SwiftUI

/// Minimal brand tokens mirrored from AtollDesign/BrandColors so AtollTalk
/// stays visually aligned without pulling in AtollCore/Supabase.
extension Color {
  init(hex: UInt32) {
    let r = Double((hex >> 16) & 0xFF) / 255
    let g = Double((hex >>  8) & 0xFF) / 255
    let b = Double( hex        & 0xFF) / 255
    self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
  }
  static let brandBlue     = Color(hex: 0x185FA5)
  static let brandBlue50   = Color(hex: 0xE6F1FB)
  static let textPrimary   = Color(hex: 0x1A1A1A)
  static let textSecondary = Color(hex: 0x4A4A4A)
  static let textTertiary  = Color(hex: 0x888780)
}
