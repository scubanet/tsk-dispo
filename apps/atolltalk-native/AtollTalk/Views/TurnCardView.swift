import SwiftUI

struct TurnCardView: View {
  let turn: Turn
  let prominent: Bool
  let onSpeak: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top, spacing: 6) {
        Text(turn.sourceLang.flag)
        Text(turn.sourceText)
          .foregroundStyle(Color.textTertiary)
          .lineLimit(prominent ? nil : 1)
          .fixedSize(horizontal: false, vertical: prominent)
      }
      .font(prominent ? .body : .footnote)

      Text("\(turn.targetLang.flag) \(turn.targetLang.displayName.uppercased())")
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.brandBlue)

      Text(turn.targetText)
        .font(prominent ? .system(.largeTitle, weight: .bold) : .headline)
        .foregroundStyle(Color.textPrimary)
        .fixedSize(horizontal: false, vertical: true)

      if prominent {
        Button(action: onSpeak) {
          Label("Vorlesen", systemImage: "speaker.wave.2.fill")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color.brandBlue)
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .opacity(prominent ? 1 : 0.7)
  }
}
