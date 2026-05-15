import SwiftUI

/// ATOLL Logo — renders the official brand mark from `Assets.xcassets/AtollLogo`.
///
/// Mirrors the web-app `<Logo>` component: real brand mark only, no synthetic
/// fallback. If the asset is missing, an empty placeholder is rendered so the
/// surrounding layout doesn't jump.
///
/// The image asset `AtollLogo` lives in the consuming app's `Assets.xcassets`
/// (apps/atoll-ios/ATOLL/Resources/Assets.xcassets). The package resolves it
/// from the main bundle at runtime.
///
/// To swap the logo everywhere, replace the PNGs in `AtollLogo.imageset/`.
public struct AtollLogo: View {
  public var size: CGFloat
  public var bare: Bool

  public init(size: CGFloat = 48, bare: Bool = false) {
    self.size = size
    self.bare = bare
  }

  // The legacy `bare` parameter is kept for source-compat with old callsites
  // but no longer changes anything (no rounded-square background to suppress).
  public var body: some View {
    Image("AtollLogo")
      .resizable()
      .renderingMode(.original)
      .scaledToFit()
      .frame(width: size, height: size)
  }
}

#Preview {
  HStack(spacing: 20) {
    AtollLogo(size: 32)
    AtollLogo(size: 64)
    AtollLogo(size: 128)
  }
  .padding()
}
