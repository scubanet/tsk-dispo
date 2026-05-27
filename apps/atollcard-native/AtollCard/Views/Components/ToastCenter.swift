import SwiftUI
import Observation

/// Lightweight toast pipeline — show transient banners ("Karte kopiert",
/// "NFC-Tag geschrieben", "Lead in Address Book importiert").
@MainActor
@Observable
public final class ToastCenter {
  public private(set) var current: Toast?

  public init() {}

  public func show(_ message: String, kind: Toast.Kind = .info) {
    let id = UUID()
    current = Toast(id: id, message: message, kind: kind)
    Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(2.6))
      guard let self else { return }
      if self.current?.id == id { self.current = nil }
    }
  }

  public struct Toast: Identifiable, Equatable {
    public let id: UUID
    public let message: String
    public let kind: Kind
    public enum Kind: Equatable { case info, success, error }
  }
}

extension View {
  /// Attach the toast banner overlay anywhere the `ToastCenter` is in scope.
  func toastBanner(from center: ToastCenter) -> some View {
    overlay(alignment: .top) {
      if let toast = center.current {
        ToastBanner(toast: toast)
          .transition(.move(edge: .top).combined(with: .opacity))
          .padding(.top, 8)
      }
    }
    .animation(.spring(duration: 0.25), value: center.current)
  }
}

private struct ToastBanner: View {
  let toast: ToastCenter.Toast

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: icon)
        .font(.system(size: 14, weight: .bold))
      Text(toast.message)
        .font(.system(size: 14, weight: .medium))
    }
    .foregroundStyle(.white)
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .background(bg, in: Capsule())
    .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
    .padding(.horizontal, 24)
  }

  private var icon: String {
    switch toast.kind {
    case .info:    "info.circle.fill"
    case .success: "checkmark.circle.fill"
    case .error:   "exclamationmark.triangle.fill"
    }
  }

  private var bg: Color {
    switch toast.kind {
    case .info:    Color.primary
    case .success: .cardPillGreenText
    case .error:   .cardPillRoseText
    }
  }
}
