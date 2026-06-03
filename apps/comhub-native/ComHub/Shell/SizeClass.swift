import SwiftUI

/// Plattformkorrekte Kompakt-Erkennung: horizontalSizeClass == .compact auf iOS,
/// auf macOS immer false (keine Groessenklassen → Wide-Layout).
struct CompactWidthReader<Content: View>: View {
  @ViewBuilder let content: (Bool) -> Content
  #if os(iOS)
  @Environment(\.horizontalSizeClass) private var hSize
  private var compact: Bool { hSize == .compact }
  #else
  private var compact: Bool { false }
  #endif
  var body: some View { content(compact) }
}
