import SwiftUI
import SwiftData

struct RootView: View {
  @Environment(\.modelContext) private var modelContext
  let settings: SettingsStore
  let glossary: GlossaryStore
  let subscription: SubscriptionStore

  private let secrets: SecretStore = KeychainSecretStore()
  @State private var vm: AppViewModel?
  @State private var showSettings = false

  var body: some View {
    Group {
      if let vm {
        ConversationView(vm: vm, settings: settings) { showSettings = true }
          .alert("Hinweis", isPresented: errorBinding(vm)) {
            Button("OK", role: .cancel) {}
          } message: { Text(errorText(vm)) }
      } else {
        ProgressView()
      }
    }
    .task { rebuild() }
    .onChange(of: subscription.isPro) { rebuild() }
    .sheet(isPresented: $showSettings, onDismiss: rebuild) {
      SettingsView(secrets: secrets, settings: settings, glossary: glossary)
    }
    .overlay(alignment: .top) {
      if !hasKeys { keyBanner }
    }
  }

  private var hasKeys: Bool {
    let hasEleven = secrets.value(for: .elevenLabsAPIKey)?.isEmpty == false
    let hasAnthropic = secrets.value(for: .anthropicAPIKey)?.isEmpty == false
    // ElevenLabs is always needed (Scribe STT). Anthropic only for Pro (Claude).
    return hasEleven && (hasAnthropic || !subscription.isPro)
  }

  private var keyBanner: some View {
    Button { showSettings = true } label: {
      Text("API-Schlüssel fehlen — hier eintragen")
        .font(.footnote.weight(.medium))
        .padding(8).frame(maxWidth: .infinity)
        .background(Color.brandBlue50)
        .foregroundStyle(Color.brandBlue)
    }
    .buttonStyle(.plain)
  }

  private func rebuild() {
    let el = secrets.value(for: .elevenLabsAPIKey) ?? ""
    let an = secrets.value(for: .anthropicAPIKey) ?? ""
    let isPro = subscription.isPro
    vm = AppViewModel(
      recorder: AudioRecorder(),
      speech: SpeechService(apiKey: el),
      translator: ServiceFactory.translator(isPro: isPro, anthropicKey: an, model: settings.model),
      synthesis: SynthesisService(elevenLabsKey: el, voices: settings.voices,
                                  tier: isPro ? .pro : .basic),
      store: ConversationStore(context: modelContext),
      context: settings.context,
      glossaryLines: { glossary.promptLines(for: settings.pair) },
      pair: { settings.pair }
    )
  }

  private func errorBinding(_ vm: AppViewModel) -> Binding<Bool> {
    Binding(get: { if case .error = vm.phase { return true } else { return false } },
            set: { if !$0 { vm.phaseResetToIdle() } })
  }
  private func errorText(_ vm: AppViewModel) -> String {
    if case let .error(msg) = vm.phase { return msg }; return ""
  }
}
