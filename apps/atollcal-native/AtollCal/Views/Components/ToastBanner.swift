import SwiftUI

/// Lightweight global toast surface. Inject as `.environment(toastCenter)` at
/// the app root and call `show(_:)` from anywhere to surface a transient
/// error/info message. The banner auto-dismisses after `defaultDuration`.
@MainActor
@Observable
final class ToastCenter {
  var message: ToastMessage?

  private let defaultDuration: Duration = .seconds(3)

  func show(_ text: String, kind: ToastMessage.Kind = .error) {
    let m = ToastMessage(text: text, kind: kind)
    message = m
    Task { @MainActor in
      try? await Task.sleep(for: defaultDuration)
      // Only clear if our message is still the active one — a newer toast
      // (different id) must not be hidden by this delayed dismiss.
      if message?.id == m.id {
        message = nil
      }
    }
  }
}

struct ToastMessage: Identifiable, Equatable {
  let id = UUID()
  let text: String
  let kind: Kind

  enum Kind { case info, warning, error }

  var iconName: String {
    switch kind {
    case .info: return "info.circle.fill"
    case .warning: return "exclamationmark.triangle.fill"
    case .error: return "xmark.octagon.fill"
    }
  }

  var tint: Color {
    switch kind {
    case .info: return .accentColor
    case .warning: return .orange
    case .error: return .red
    }
  }
}

private struct ToastBannerView: View {
  let message: ToastMessage

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: message.iconName)
        .foregroundStyle(message.tint)
      Text(message.text)
        .font(.callout)
        .foregroundStyle(.primary)
        .lineLimit(2)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(.thinMaterial)
    .clipShape(.capsule)
    .overlay(
      Capsule().strokeBorder(message.tint.opacity(0.4), lineWidth: 0.5)
    )
    .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
    .padding(.top, 12)
  }
}

extension View {
  /// Anchors a transient banner at the top of the view, driven by the given
  /// `ToastCenter`. Apply once at the app root.
  func toastBanner(from center: ToastCenter) -> some View {
    overlay(alignment: .top) {
      if let m = center.message {
        ToastBannerView(message: m)
          .transition(.move(edge: .top).combined(with: .opacity))
      }
    }
    .animation(.spring(duration: 0.3), value: center.message?.id)
  }
}
