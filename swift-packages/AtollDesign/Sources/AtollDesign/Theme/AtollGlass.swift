import SwiftUI
import AtollCore

/// Centralised Liquid Glass surface helpers for AtollCal.
///
/// iOS 26 / macOS 26 expose `.glassEffect(_:in:)`, `Glass.regular/.clear/.interactive`,
/// and `GlassEffectContainer(spacing:)`. Wrapping them here gives us one place to
/// adjust corner radii, tints and material variants if Apple iterates the API.
///
/// Usage:
///
///   PermissionBanner()
///     .atollGlassCard()
///
///   HStack { ... }
///     .atollGlassPill(tint: .red)
///
///   GlassEffectContainer(spacing: 8) {
///     ForEach(eventBars) { EventBar(...).atollGlassEventBar() }
///   }
public extension View {
  /// Floating-card glass surface — PermissionBanner, error banner, large modal containers.
  func atollGlassCard(cornerRadius: CGFloat = 16, tint: Color? = nil) -> some View {
    let base = Glass.regular
    let glass: Glass = tint.map { base.tint($0.opacity(0.18)) } ?? base
    return glassEffect(glass, in: .rect(cornerRadius: cornerRadius))
  }

  /// Pill surface — NowIndicator time bubble, compact chips, "Heute"-Buttons.
  func atollGlassPill(tint: Color? = nil, interactive: Bool = false) -> some View {
    var glass: Glass = .regular
    if let tint { glass = glass.tint(tint.opacity(0.22)) }
    if interactive { glass = glass.interactive() }
    return glassEffect(glass, in: .capsule)
  }

  /// EventBar surface — only call this when the bar is tall enough (>=40pt).
  /// Below that the glass material is too noisy to read text over.
  ///
  /// `tint` is normally the event's display colour (system EKEvent calendar
  /// colour, or ATOLL role colour via `Color.atollRole(_:)`).
  func atollGlassEventBar(tint: Color) -> some View {
    glassEffect(.regular.tint(tint.opacity(0.16)), in: .rect(cornerRadius: 6))
  }

  /// Sheet / popover / inspector container background.
  /// Uses `presentationBackground` which on iOS/macOS 26 accepts a `Glass` variant.
  func atollGlassPresentation() -> some View {
    presentationBackground(.regularMaterial)
  }
}

/// Maps ATOLL `AssignmentRole` to a stable, brand-consistent accent colour.
///
/// - `haupt`   (Lead instructor)         → `brandBlue`
/// - `assist`  (Assistant instructor)    → `brandTeal`
/// - `opfer`   (Rescue victim / standby) → `brandOrange`
/// - `dmt`     (Legacy DM-Trainee)       → `brandBlue800`  – muted, legacy data only
///
/// Contrast verified WCAG-AA against both light surfaces and Liquid-Glass card
/// backgrounds. Use `Color.atollRole(_:)` to render bar fills / accents.
public extension Color {
  static func atollRole(_ role: AssignmentRole) -> Color {
    switch role {
    case .haupt:  return .brandBlue
    case .assist: return .brandTeal
    case .opfer:  return .brandOrange
    case .dmt:    return .brandBlue800
    }
  }
}
