import SwiftUI

/// First-launch consent for cloud processing. Required before any cloud call
/// (Scribe STT, Claude translation, ElevenLabs voices) per App Review policy.
struct ConsentView: View {
  let onAccept: () -> Void

  var body: some View {
    VStack(spacing: 24) {
      Spacer()
      Image(systemName: "lock.shield")
        .font(.system(size: 56))
        .foregroundStyle(Color.brandBlue)
      Text("Datenverarbeitung").font(.largeTitle.bold())
      Text("""
      AtollTalk sendet deine Sprachaufnahmen und Texte zur Erkennung, Übersetzung \
      und Sprachausgabe an Cloud-Dienste (ElevenLabs, Anthropic). Ohne Zustimmung \
      findet keine Verarbeitung statt.
      """)
        .multilineTextAlignment(.center)
        .foregroundStyle(Color.textSecondary)
        .padding(.horizontal)
      Spacer()
      Button(action: onAccept) {
        Text("Zustimmen und starten")
          .font(.headline)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 16)
          .background(Color.brandBlue, in: .rect(cornerRadius: 14))
          .foregroundStyle(.white)
      }
      Link("Datenschutzerklärung", destination: URL(string: "https://atoll-os.com/privacy")!)
        .font(.footnote)
        .foregroundStyle(Color.textSecondary)
    }
    .padding(24)
    .background(Color(hex: 0xFAF9F4))
    .interactiveDismissDisabled()
  }
}
