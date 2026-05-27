import SwiftUI

/// Coloured avatar circle with initials. Uses the same parsing trick as
/// `AtollDesign.AvatarView` but is a thin local copy because the AtollDesign
/// gradient is more elaborate than we need here.
struct Avatar: View {
  let initials: String
  let colorHex: String?
  var size: CGFloat? = nil

  var body: some View {
    let base = Color(hex: colorHex ?? "") ?? .gray
    GeometryReader { geo in
      let s = size ?? min(geo.size.width, geo.size.height)
      Circle()
        .fill(LinearGradient(
          colors: [base, base.opacity(0.8)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        ))
        .frame(width: s, height: s)
        .overlay(
          Text(initials)
            .font(.system(size: s * 0.38, weight: .bold))
            .foregroundStyle(.white)
        )
    }
    .aspectRatio(1, contentMode: .fit)
  }
}

#Preview {
  HStack {
    Avatar(initials: "DW", colorHex: "#b03844").frame(width: 44, height: 44)
    Avatar(initials: "MK", colorHex: "#b8893a").frame(width: 36, height: 36)
    Avatar(initials: "AN", colorHex: "#5fa86a").frame(width: 36, height: 36)
  }
  .padding()
}
