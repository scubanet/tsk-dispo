import SwiftUI
import AtollDesign

/// AtollCal-style floating action bar: 4 capsule cells in one frosted capsule
/// at the bottom of the screen — burger menu · persona · search · plus.
struct FloatingActionBar: View {
  /// Offline-queue CacheStore, injected from `AtollCardApp`. Optional because
  /// the App's container init can fail (degraded path) — when nil, no badge
  /// is shown. Reading via `@Environment(CacheStore.self)` returns the same
  /// `CacheStore?` the App injects.
  @Environment(CacheStore.self) private var cacheStore: CacheStore?

  let personInitials: String
  let personName: String
  let personColorHex: String?

  var onMenuTap:   () -> Void = {}
  var onAvatarTap: () -> Void = {}
  var onSearchTap: () -> Void = {}
  var onAddTap:    () -> Void = {}

  var body: some View {
    HStack(spacing: 4) {
      circle(icon: "line.3.horizontal", style: .soft, action: onMenuTap)
      HStack(spacing: 8) {
        Avatar(initials: personInitials, colorHex: personColorHex)
          .frame(width: 36, height: 36)
          .overlay(alignment: .topTrailing) {
            // Read the count lazily on each redraw — `@Observable`-driven
            // changes in `CacheStore` re-evaluate this view automatically.
            PendingBadge(count: cacheStore?.pendingCount() ?? 0)
              .offset(x: 6, y: -2)
          }
        Text(personName)
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(Color(hex: 0x2563EB))
          .lineLimit(1)
      }
      .padding(.horizontal, 6)
      .onTapGesture { onAvatarTap() }
      Spacer(minLength: 4)
      circle(icon: "magnifyingglass", style: .soft, action: onSearchTap)
      circle(icon: "plus", style: .dark, action: onAddTap)
    }
    .padding(6)
    .background(
      Capsule()
        .fill(.regularMaterial)
    )
    .overlay(
      Capsule().stroke(.black.opacity(0.04), lineWidth: 1)
    )
    .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
    .padding(.horizontal, 16)
  }

  private enum CircleStyle { case soft, dark }

  @ViewBuilder
  private func circle(icon: String, style: CircleStyle, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: icon)
        .font(.system(size: 16, weight: .bold))
        .foregroundStyle(style == .soft ? Color.primary : .white)
        .frame(width: 44, height: 44)
        .background(
          Circle().fill(style == .soft ? Color.cardSoftBackground : Color.primary)
        )
    }
    .buttonStyle(.plain)
  }
}

#Preview {
  ZStack(alignment: .bottom) {
    Color.cardPageBackground.ignoresSafeArea()
    FloatingActionBar(
      personInitials: "DW",
      personName: "Dominik",
      personColorHex: "#b03844"
    )
    .padding(.bottom, 24)
  }
}
