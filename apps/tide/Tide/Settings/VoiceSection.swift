import SwiftUI
import AVFoundation
import Core

struct VoiceSection: View {
  @State private var settings = AppSettings()

  private var availableVoices: [AVSpeechSynthesisVoice] {
    AVSpeechSynthesisVoice.speechVoices()
      .filter { $0.language.hasPrefix("de") || $0.language.hasPrefix("en") }
      .sorted { $0.name < $1.name }
  }

  var body: some View {
    Form {
      Section {
        Toggle("Antworten vorlesen", isOn: Binding(
          get: { settings.voiceEnabled },
          set: { settings.voiceEnabled = $0 }
        ))
        Picker("Stimme:", selection: Binding(
          get: { settings.voiceIdentifier },
          set: { settings.voiceIdentifier = $0 }
        )) {
          ForEach(availableVoices, id: \.identifier) { voice in
            Text("\(voice.name) (\(voice.language))").tag(voice.identifier)
          }
        }
        .disabled(!settings.voiceEnabled)
      } header: {
        Text("Text-to-Speech")
      }

      Section {
        Toggle("Selektion standardmäßig ersetzen", isOn: Binding(
          get: { settings.replaceSelectionByDefault },
          set: { settings.replaceSelectionByDefault = $0 }
        ))
        Text("Wenn aktiv, ersetzt Tide den markierten Text automatisch nach dem Senden, statt einen 'Ersetzen'-Button zu zeigen.")
          .font(.caption)
          .foregroundStyle(.secondary)
      } header: {
        Text("Selektions-Verhalten")
      }
    }
    .formStyle(.grouped)
  }
}
