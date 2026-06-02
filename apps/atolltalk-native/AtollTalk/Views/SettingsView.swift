import SwiftUI

struct SettingsView: View {
  @Environment(\.dismiss) private var dismiss
  let secrets: SecretStore
  let settings: SettingsStore
  let glossary: GlossaryStore

  @State private var elevenKey = ""
  @State private var anthropicKey = ""
  @State private var newDE = ""
  @State private var newUK = ""

  var body: some View {
    NavigationStack {
      Form {
        Section("API-Schlüssel") {
          SecureField("ElevenLabs API-Key", text: $elevenKey)
          SecureField("Anthropic API-Key", text: $anthropicKey)
        }
        Section("Übersetzungsmodell") {
          Picker("Claude-Modell", selection: Binding(
            get: { settings.model }, set: { settings.model = $0 })) {
            ForEach(settings.modelOptions, id: \.self) { Text($0).tag($0) }
          }
        }
        Section("Stimmen (ElevenLabs Voice-IDs)") {
          TextField("Voice-ID Deutsch", text: Binding(
            get: { settings.voiceDE }, set: { settings.voiceDE = $0 }))
          TextField("Voice-ID Ukrainisch", text: Binding(
            get: { settings.voiceUK }, set: { settings.voiceUK = $0 }))
        }
        Section("Glossar") {
          ForEach(glossary.entries) { e in
            HStack { Text(e.de); Spacer(); Text(e.uk).foregroundStyle(.secondary) }
          }
          .onDelete { idx in idx.map { glossary.entries[$0] }.forEach(glossary.remove) }
          HStack {
            TextField("Deutsch", text: $newDE)
            TextField("Українська", text: $newUK)
            Button("＋") {
              guard !newDE.isEmpty, !newUK.isEmpty else { return }
              glossary.add(de: newDE, uk: newUK); newDE = ""; newUK = ""
            }
          }
        }
        Section("Kontext") {
          TextEditor(text: Binding(get: { settings.context }, set: { settings.context = $0 }))
            .frame(minHeight: 100)
        }
      }
      .navigationTitle("Einstellungen")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Fertig") {
            secrets.set(elevenKey.isEmpty ? nil : elevenKey, for: .elevenLabsAPIKey)
            secrets.set(anthropicKey.isEmpty ? nil : anthropicKey, for: .anthropicAPIKey)
            dismiss()
          }
        }
      }
      .onAppear {
        elevenKey = secrets.value(for: .elevenLabsAPIKey) ?? ""
        anthropicKey = secrets.value(for: .anthropicAPIKey) ?? ""
      }
    }
  }
}
