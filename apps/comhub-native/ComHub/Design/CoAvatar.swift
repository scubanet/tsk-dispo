import SwiftUI
import AtollHub

/// Runder Initialen-Avatar mit Farb-Gradient (deterministisch aus dem Namen).
struct CoAvatar: View {
  let name: String
  var size: CGFloat = 34
  var color: Color? = nil

  var body: some View {
    let base = color ?? CoColor.avatarColor(for: name)
    Circle()
      .fill(LinearGradient(colors: [base, base.opacity(0.78)],
                           startPoint: .topLeading, endPoint: .bottomTrailing))
      .frame(width: size, height: size)
      .overlay(
        Text(Initials.from(name))
          .font(.system(size: size * 0.4, weight: .semibold))
          .foregroundStyle(.white)
      )
  }
}
