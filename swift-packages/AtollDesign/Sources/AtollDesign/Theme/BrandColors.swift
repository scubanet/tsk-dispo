import SwiftUI

/// ATOLL Brand Colors — mirrors the web Foundation token system from
/// `apps/web/src/styles/tokens.css` so iOS and Web stay visually aligned.
///
/// Naming: `Color.brandBlue` / `.brandTeal` / `.brandAmber` / `.brandRed`
/// / `.brandPurple` / `.brandPink` / `.brandDeep` / `.brandSand` etc.
///
/// Each hue exposes:
///   - base color           (e.g. `.brandBlue`)
///   - 50  (very light bg)  (e.g. `.brandBlue50`)
///   - 100 (light bg)       (e.g. `.brandBlue100`)
///   - 800 (dark text)      (e.g. `.brandBlue800`)
///   - 900 (deepest)        (e.g. `.brandBlue900`)
///
/// Use via `Color.brandTeal50` etc. — works in light + dark mode unchanged.
public extension Color {
  // ─────────────── Brand Blue (primary action, OWD/AOWD) ───────────────
  static let brandBlue     = Color(hex: 0x185FA5)
  static let brandBlue50   = Color(hex: 0xE6F1FB)
  static let brandBlue100  = Color(hex: 0xB5D4F4)
  static let brandBlue800  = Color(hex: 0x0C447C)
  static let brandBlue900  = Color(hex: 0x042C53)

  // ─────────────── Brand Deep (hero KPI bg, brand anchor) ───────────────
  static let brandDeep     = Color(hex: 0x042C53)

  // ─────────────── Brand Teal (success, specialty, rescue) ───────────────
  static let brandTeal     = Color(hex: 0x1D9E75)
  static let brandTeal50   = Color(hex: 0xE1F5EE)
  static let brandTeal100  = Color(hex: 0x9FE1CB)
  static let brandTeal800  = Color(hex: 0x085041)

  // ─────────────── Brand Amber (warning, tentative) ───────────────
  static let brandAmber    = Color(hex: 0xBA7517)
  static let brandAmber50  = Color(hex: 0xFAEEDA)
  static let brandAmber100 = Color(hex: 0xFAC775)
  static let brandAmber800 = Color(hex: 0x633806)

  // ─────────────── Brand Red (danger, blocked) ───────────────
  static let brandRed      = Color(hex: 0xA32D2D)
  static let brandRed50    = Color(hex: 0xFCEBEB)
  static let brandRed100   = Color(hex: 0xF7C1C1)
  static let brandRed800   = Color(hex: 0x791F1F)

  // ─────────────── Brand Purple (Pro/DM) ───────────────
  static let brandPurple   = Color(hex: 0x534AB7)
  static let brandPurple50 = Color(hex: 0xEEEDFE)
  static let brandPurple800 = Color(hex: 0x3C3489)

  // ─────────────── Brand Pink (CD/OWSI/IDC, SPEI) ───────────────
  static let brandPink     = Color(hex: 0xD4537E)
  static let brandPink50   = Color(hex: 0xFBEAF0)
  static let brandPink800  = Color(hex: 0x72243E)

  // ─────────────── Brand Sand (page bg, sidebar) ───────────────
  static let brandSand     = Color(hex: 0xFAF9F4)
  static let brandSand200  = Color(hex: 0xF1EFE8)

  // ─────────────── Semantic aliases ───────────────
  static let bgPage        = Color(hex: 0xF1EFE8)
  static let bgCard        = Color.white
  static let textPrimary   = Color(hex: 0x1A1A1A)
  static let textSecondary = Color(hex: 0x4A4A4A)
  static let textTertiary  = Color(hex: 0x888780)
  static let borderHairline = Color.black.opacity(0.045)
}

/// Hex initializer (e.g. `Color(hex: 0x185FA5)`).
public extension Color {
  init(hex: UInt32) {
    let r = Double((hex >> 16) & 0xFF) / 255
    let g = Double((hex >>  8) & 0xFF) / 255
    let b = Double( hex        & 0xFF) / 255
    self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
  }
}

/// Maps a PADI level string (DM, OWSI, MI, CD, …) to its avatar color.
/// Mirrors `padiLevelColor()` from `apps/web/src/foundation/lib/colors.ts`.
public extension Color {
  static func padiLevel(_ level: String?) -> Color {
    switch level {
    case "CD":            return .brandPink
    case "MI":            return .brandPurple
    case "IDC Staff":     return .brandBlue800
    case "OWSI", "MSDT", "AI":
                          return .brandBlue
    case "DM":            return .brandTeal
    case "Shop Staff":    return .brandAmber
    default:              return Color(hex: 0x5F5E5A)   // brand-gray-80
    }
  }
}
