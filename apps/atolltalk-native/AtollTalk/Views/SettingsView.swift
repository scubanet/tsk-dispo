import SwiftUI
import StoreKit

struct SettingsView: View {
  @Environment(\.dismiss) private var dismiss
  let secrets: SecretStore
  @Bindable var settings: SettingsStore
  let glossary: GlossaryStore
  let subscription: SubscriptionStore

  @State private var elevenKey = ""
  @State private var showPaywall = false
  @State private var showManage = false
  @State private var showOfferCode = false
  @State private var newA = ""
  @State private var newB = ""

  /// The active pair's two languages in stable order (matches GlossaryEntry.a/.b).
  private var glossaryLangs: (AppLanguage, AppLanguage) {
    GlossaryStore.sortedLangs(settings.pair)
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          HStack {
            Text("Tarif")
            Spacer()
            Text(subscription.isPro ? "Pro" : "Basic").foregroundStyle(.secondary)
          }
          if !subscription.isPro {
            Button("Auf Pro upgraden") { showPaywall = true }
          }
          Button("Abo verwalten") { showManage = true }
          Button("Einlösecode eingeben") { showOfferCode = true }
        } header: {
          Text("Abo")
        } footer: {
          Text(subscription.isPro
            ? "Pro: Premium-Übersetzung (Claude) + natürliche Stimmen, alle Sprachen."
            : "Basic: Standard-Übersetzung (on-device), \(Config.basicDailyLimit) Übersetzungen/Tag.")
        }
        Section("API-Schlüssel") {
          SecureField("ElevenLabs API-Key", text: $elevenKey)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        }
        Section("Übersetzungsmodell") {
          Picker("Claude-Modell", selection: $settings.model) {
            ForEach(settings.modelOptions, id: \.self) { Text($0).tag($0) }
          }
        }
        Section {
          ForEach(AppLanguage.allCases) { lang in
            HStack {
              Text("\(lang.flag) \(lang.displayName)").foregroundStyle(.secondary)
              Spacer()
              TextField(
                lang.defaultElevenVoiceID,   // placeholder = active default
                text: Binding(
                  get: { settings.voiceID(for: lang) },
                  set: { settings.setVoiceID($0, for: lang) }))
                .multilineTextAlignment(.trailing)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            }
          }
        } header: {
          Text("Stimmen (ElevenLabs Voice-IDs)")
        } footer: {
          Text("Leer = hinterlegte Standardstimme. Eintrag überschreibt pro Sprache.")
        }
        Section {
          ForEach(glossary.entries(for: settings.pair)) { e in
            HStack { Text(e.a); Spacer(); Text(e.b).foregroundStyle(.secondary) }
          }
          .onDelete { idx in
            idx.map { glossary.entries(for: settings.pair)[$0] }
              .forEach { glossary.remove($0, for: settings.pair) }
          }
          HStack {
            TextField(glossaryLangs.0.displayName, text: $newA)
            TextField(glossaryLangs.1.displayName, text: $newB)
            Button("Begriff hinzufügen", systemImage: "plus") {
              guard !newA.isEmpty, !newB.isEmpty else { return }
              glossary.add(for: settings.pair) { $0 == glossaryLangs.0 ? newA : newB }
              newA = ""; newB = ""
            }
            .labelStyle(.iconOnly)
            .disabled(newA.isEmpty || newB.isEmpty)
          }
        } header: {
          Text("Glossar \(glossaryLangs.0.flag) \(glossaryLangs.1.flag)")
        } footer: {
          Text("Begriffe für das aktuelle Sprach-Paar — wird beim Übersetzen fix angewendet.")
        }
        Section("Kontext") {
          TextEditor(text: $settings.context)
            .frame(minHeight: 100)
        }
      }
      .navigationTitle("Einstellungen")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Fertig") {
            secrets.set(elevenKey.isEmpty ? nil : elevenKey, for: .elevenLabsAPIKey)
            dismiss()
          }
        }
      }
      .onAppear {
        elevenKey = secrets.value(for: .elevenLabsAPIKey) ?? ""
      }
      .sheet(isPresented: $showPaywall) { PaywallView(subscription: subscription) }
      .manageSubscriptionsSheet(isPresented: $showManage)
      .offerCodeRedemption(isPresented: $showOfferCode)
    }
  }
}
