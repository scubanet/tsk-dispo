import SwiftUI

/// Karten-Container im Mockup-Stil: content-bg, Hairline-Rahmen, weicher Schatten.
struct CoCard<Content: View>: View {
  @ViewBuilder var content: () -> Content
  var body: some View {
    content()
      .background(.background, in: RoundedRectangle(cornerRadius: CoTheme.cardRadius))
      .overlay(
        RoundedRectangle(cornerRadius: CoTheme.cardRadius)
          .strokeBorder(CoTheme.separator, lineWidth: 1)
      )
      .shadow(color: CoTheme.cardShadowColor, radius: CoTheme.cardShadowRadius,
              x: 0, y: CoTheme.cardShadowY)
  }
}
