import SwiftUI

/// Kleiner Icon-Knopf mit voller, zuverlaessiger Trefferflaeche (>=30pt) — ersetzt
/// blanke `Button { } label: { Image(...) }`, deren Trefferflaeche zu klein ist.
struct IconButton: View {
  let systemName: String
  var size: CGFloat = 16
  var help: String? = nil
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      Image(systemName: systemName)
        .font(.system(size: size, weight: .medium))
        .frame(width: 30, height: 30)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .modifier(OptionalHelp(help: help))
  }
}
private struct OptionalHelp: ViewModifier {
  let help: String?
  func body(content: Content) -> some View {
    if let help { content.help(help) } else { content }
  }
}
