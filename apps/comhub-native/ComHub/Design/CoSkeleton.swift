import SwiftUI

/// Schlichte Platzhalter-Zeilen waehrend des Ladens (statt leerer Flaeche/Flackern).
struct CoSkeletonRows: View {
  var count: Int = 6
  var body: some View {
    VStack(spacing: 0) {
      ForEach(0..<count, id: \.self) { _ in
        HStack(spacing: 11) {
          Circle().fill(.quaternary).frame(width: 30, height: 30)
          VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 4).fill(.quaternary).frame(width: 160, height: 11)
            RoundedRectangle(cornerRadius: 4).fill(.quaternary).frame(width: 100, height: 9)
          }
          Spacer(minLength: 0)
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
        Divider().opacity(0.4)
      }
    }
    .redacted(reason: .placeholder)
    .shimmer()
    .accessibilityHidden(true)
  }
}

/// Dezenter Shimmer-Sweep ueber Platzhalter.
private struct Shimmer: ViewModifier {
  @State private var phase: CGFloat = -1
  func body(content: Content) -> some View {
    content.overlay(
      GeometryReader { geo in
        let w = geo.size.width
        LinearGradient(colors: [.clear, .white.opacity(0.35), .clear],
                       startPoint: .leading, endPoint: .trailing)
          .frame(width: w * 0.6)
          .offset(x: phase * w)
          .blendMode(.plusLighter)
          .allowsHitTesting(false)
      }
    )
    .onAppear {
      withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
        phase = 1.4
      }
    }
  }
}
extension View { func shimmer() -> some View { modifier(Shimmer()) } }
