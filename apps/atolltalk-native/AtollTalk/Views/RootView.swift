import SwiftUI
import SwiftData

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
    let el = Config.elevenLabsAPIKey
    let isPro = subscription.isPro
    let sub = subscription
    vm = AppViewModel(
      recorder: AudioRecorder(),
      speech: SpeechService(apiKey: el),
      translator: ServiceFactory.translator(
        isPro: isPro, model: settings.model, jws: { await sub.currentJWS() }),
      synthesis: SynthesisService(elevenLabsKey: el, voices: settings.voices,
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
