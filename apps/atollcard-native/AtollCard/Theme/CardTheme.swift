import SwiftUI
import AtollDesign

/// AtollCard-specific design tokens layered on top of `AtollDesign.BrandColors`.
///
/// AtollDesign covers the WCAG-AA brand hues used in courses, assignments
/// and the web app. AtollCard adds the cream page background, pastel pills,
/// and persona gradients from the iOS mockup that aren't part of the core
/// brand palette.
public extension Color {

  // ─────────────── Page / surfaces (AtollCal-aligned) ───────────────

  /// Kühl-weisser Page-Hintergrund (Blau/Grau) — Glas-Look-Restyle (vorher cremig 0xFEFDFB).
  static let cardPageBackground = Color(hex: 0xEEF2F9)
  static let cardSoftBackground = Color(hex: 0xEAEEF5)

  // ─────────────── Accent / text (mockup-aligned) ───────────────

  /// Roter Akzent in den großen Titles ("Meine [Karten]") — wie AtollCal.
  static let cardAccentRed = Color(hex: 0xA8443A)
  static let cardTextMuted = Color(hex: 0x9AA3B5)
  static let cardTextSecondary = Color(hex: 0x5A6478)

  // ─────────────── Pastel pills ───────────────

  static let cardPillBlue       = Color(hex: 0xDDE8F7)
  static let cardPillBlueText   = Color(hex: 0x1E3A8A)
  static let cardPillBeige      = Color(hex: 0xEDE5D4)
  static let cardPillBeigeText  = Color(hex: 0x6B5D3F)
  static let cardPillPurple     = Color(hex: 0xE8DFF3)
  static let cardPillPurpleText = Color(hex: 0x5B3A8E)
  static let cardPillGreen      = Color(hex: 0xD8EBD9)
  static let cardPillGreenText  = Color(hex: 0x2D5A3A)
  static let cardPillRose       = Color(hex: 0xF5D9DD)
  static let cardPillRoseText   = Color(hex: 0x8C2B3A)
  static let cardPillAmber      = Color(hex: 0xF4E2C4)
  static let cardPillAmberText  = Color(hex: 0x8A5A1A)

  // ─────────────── Persona gradients ───────────────

  static let personaCDStart = Color(hex: 0x1E3A8A)
  static let personaCDEnd   = Color(hex: 0x4A8DE8)
  static let personaSEStart = Color(hex: 0x0D6E7A)
  static let personaSEEnd   = Color(hex: 0x4EC5D6)
  static let personaPrStart = Color(hex: 0x5B3A8E)
  static let personaPrEnd   = Color(hex: 0x9B6DD0)
}

/// Persona gradient resolver — pulls the right pair off `Color` so the
/// `BizCardView` can render the gradient with one `gradient(for:)` call.
public extension LinearGradient {
  static func persona(_ theme: CardTheme) -> LinearGradient {
    let pair = personaPair(for: theme)
    return LinearGradient(
      colors: [pair.start, pair.end],
      startPoint: .topLeading,
      endPoint:   .bottomTrailing
    )
  }

  private static func personaPair(for theme: CardTheme) -> (start: Color, end: Color) {
    // Custom hex pair overrides the preset entirely.
    if let s = theme.gradientStartHex, let e = theme.gradientEndHex,
       let start = Color(hex: s), let end = Color(hex: e) {
      return (start, end)
    }
    switch theme.preset {
    case .courseDirector: return (.personaCDStart, .personaCDEnd)
    case .seaExplorers:   return (.personaSEStart, .personaSEEnd)
    case .privat:         return (.personaPrStart, .personaPrEnd)
    case .custom:         return (.personaCDStart, .personaCDEnd)   // fallback
    }
  }
}

/// Pastel-pill style — pick a tone, get matching background + text.
public enum PillTone: CaseIterable, Hashable {
  case blue, beige, purple, green, rose, amber

  public var background: Color {
    switch self {
    case .blue:   .cardPillBlue
    case .beige:  .cardPillBeige
    case .purple: .cardPillPurple
    case .green:  .cardPillGreen
    case .rose:   .cardPillRose
    case .amber:  .cardPillAmber
    }
  }

  public var foreground: Color {
    switch self {
    case .blue:   .cardPillBlueText
    case .beige:  .cardPillBeigeText
    case .purple: .cardPillPurpleText
    case .green:  .cardPillGreenText
    case .rose:   .cardPillRoseText
    case .amber:  .cardPillAmberText
    }
  }

  /// Stable colour assignment for arbitrary string keys — same string always
  /// gets the same tone. Used for specialty pills on a card.
  public static func tone(for key: String) -> PillTone {
    let hash = abs(key.hashValue)
    return PillTone.allCases[hash % PillTone.allCases.count]
  }
}

/// Optional initialiser from hex string (`"#RRGGBB"` or `"RRGGBB"`).
public extension Color {
  init?(hex: String) {
    var raw = hex.trimmingCharacters(in: .whitespaces)
    if raw.hasPrefix("#") { raw.removeFirst() }
    guard let value = UInt32(raw, radix: 16) else { return nil }
    self.init(hex: value)
  }
}

// ─────────────────────────────────────────────────────────────────────────
// MARK: - Glas-Look Restyle (kühl Blau/Grau, wenig Rot, kein Rosa)
// ─────────────────────────────────────────────────────────────────────────

public extension Color {
  /// Slate-Akzent für die großen Titel ("Meine [Karten]") — ersetzt das Rot.
  static let cardTitleAccent = Color(hex: 0x37486A)

  /// Kühle Page-Verlaufsstops (Blau → Grau), kein Warm-/Rosaton.
  static let cardPageGradientTop    = Color(hex: 0xE8EFF9)
  static let cardPageGradientMid    = Color(hex: 0xEAF0F7)
  static let cardPageGradientBottom = Color(hex: 0xEEF2F6)

  /// Weiche, kühle Blobs hinter dem Glas.
  static let cardGlassBlob      = Color(hex: 0xB8D2F6)
  static let cardGlassBlobSteel = Color(hex: 0xCDD9EA)
}

/// Frosted-Glass-Oberfläche: durchscheinendes Material, helle Kante, weicher
/// Schatten. Liegt über `GlassBackground`, damit der Blur den kühlen Verlauf
/// aufnimmt.
public struct GlassCardModifier: ViewModifier {
  var cornerRadius: CGFloat = 22
  public func body(content: Content) -> some View {
    content
      .background(.ultraThinMaterial,
                  in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .stroke(Color.white.opacity(0.55), lineWidth: 1)
      )
      .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 8)
  }
}

public extension View {
  /// AtollCard Frosted-Glass-Surface anwenden.
  func glassCard(cornerRadius: CGFloat = 22) -> some View {
    modifier(GlassCardModifier(cornerRadius: cornerRadius))
  }
}

/// Kühler Blau/Grau-Hintergrund mit weichen Blur-Blobs — Basis-Layer hinter
/// den Haupt-Surfaces (Cards / Leads / Analytics). Kein Rosa/Lavendel.
public struct GlassBackground: View {
  public init() {}
  public var body: some View {
    LinearGradient(
      colors: [.cardPageGradientTop, .cardPageGradientMid, .cardPageGradientBottom],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
    .overlay(alignment: .topTrailing) {
      blob(.cardGlassBlob, size: 260, blur: 70, opacity: 0.7, dx: 60, dy: -40)
    }
    .overlay(alignment: .bottomLeading) {
      blob(.cardGlassBlobSteel, size: 240, blur: 70, opacity: 0.6, dx: -50, dy: 40)
    }
    .overlay(alignment: .topLeading) {
      blob(.cardGlassBlob, size: 200, blur: 75, opacity: 0.45, dx: -40, dy: 120)
    }
  }

  private func blob(_ color: Color, size: CGFloat, blur: CGFloat,
                    opacity: Double, dx: CGFloat, dy: CGFloat) -> some View {
    Circle()
      .fill(color)
      .frame(width: size, height: size)
      .blur(radius: blur)
      .opacity(opacity)
      .offset(x: dx, y: dy)
      .allowsHitTesting(false)
  }
}
