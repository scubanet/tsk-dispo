import SwiftUI

/// Shared visual style for cards in the Profile tab. Apply via
/// `.profileCardStyle()` so padding, background and corner-radius stay
/// identical across all sub-cards. Adjust this single file if profile-tab
/// card styling changes.
///
/// Tokens used:
///   padding        → DSSpacing.l  (16 pt)
///   corner-radius  → DSRadius.xl  (20 pt)
///   background     → .ultraThinMaterial via glassCard — same as stampCard
///
/// Note: profileCard intentionally uses DSSpacing.xxl (32 pt) padding as it
/// is the hero identity card; that divergence is preserved in ProfileTab.swift.
struct ProfileCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(DSSpacing.l)
            .glassCard(cornerRadius: DSRadius.xl)
    }
}

extension View {
    /// Apply the standard Profile-tab card style.
    func profileCardStyle() -> some View {
        modifier(ProfileCardStyle())
    }
}
