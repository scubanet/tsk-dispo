import SwiftUI
import SwiftData
import AtollSpeech

struct RootView: View {
  @Environment(\.modelContext) private var modelContext
  let settings: SettingsStore
  let glossary: GlossaryStore
  let subscription: SubscriptionStore

  @State private var vm: AppViewModel?
  @State private var showSettings = false

  var body: some View {
    Group {
      if let vm {
        ConversationView(vm: vm, settings: settings, subscription: subscription) { showSettings = true }
          .alert("Hinweis", isPresented: errorBinding(vm)) {
            Button("OK", role: .cancel) {}
          } message: { Text(errorText(vm)) }
      } else {
        ProgressView()
      }
    }
    .task { rebuild() }
    .onChange(of: subscription.isPro) { rebuild() }
    .fullScreenCover(isPresented: Binding(
      get: { !settings.hasConsented }, set: { _ in })) {
      ConsentView { settings.hasConsented = true }
    }
    .sheet(isPresented: $showSettings, onDismiss: rebuild) {
      SettingsView(settings: settings, glossary: glossary, subscription: subscription)
    }
  }

  private func rebuild() {
    let isPro = subscription.isPro
    let sub = subscription
    // Speech proxy: ElevenLabs key lives server-side. Free authenticates with
    // the anonymous install id; Pro additionally sends the StoreKit JWS.
    let speechBackend = ProxySpeechClient(
      baseURL: Config.speechProxyURL,
      deviceID: DeviceID.current,
      jws: {
        guard isPro else { return nil }
        return await sub.currentJWS()
      }
    )
    vm = AppViewModel(
      recorder: AudioRecorder(),
      speech: SpeechService(client: speechBackend),
      translator: ServiceFactory.translator(
        isPro: isPro, model: settings.model, jws: { await sub.currentJWS() }),
      synthesis: SynthesisService(backend: isPro ? speechBackend : nil,
                                  voices: settings.voices,
                                  tier: isPro ? .pro : .basic),
      store: ConversationStore(context: modelContext),
      context: settings.context,
      glossaryLines: { glossary.promptLines(for: settings.pair) },
      pair: { settings.pair },
      consent: { settings.hasConsented }
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
