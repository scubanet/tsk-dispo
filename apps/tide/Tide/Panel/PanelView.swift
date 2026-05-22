import SwiftUI
import Core
import LLM

struct PanelView: View {
  let conversationStore: ConversationStore
  @State private var hasKey: Bool = KeychainHelper.get(key: "anthropic.api_key") != nil
  @State private var chatViewModel: ChatViewModel?

  var body: some View {
    VStack(spacing: 0) {
      TopBar(onNew: {
        chatViewModel?.startNew()
      })
      Divider()
      if hasKey, let vm = chatViewModel {
        ChatContainer(viewModel: vm)
      } else if hasKey {
        ProgressView()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ApiKeyPromptView(hasKey: $hasKey)
      }
    }
    .frame(width: 400, height: 560)
    .onAppear {
      if chatViewModel == nil && hasKey {
        chatViewModel = makeViewModel()
      }
    }
    .onChange(of: hasKey) { _, newValue in
      if newValue && chatViewModel == nil {
        chatViewModel = makeViewModel()
      }
    }
  }

  private func makeViewModel() -> ChatViewModel {
    let apiKey = KeychainHelper.get(key: "anthropic.api_key") ?? ""
    let provider = AnthropicProvider(apiKey: apiKey)
    let settings = AppSettings()
    return ChatViewModel(
      conversationStore: conversationStore,
      provider: provider,
      settings: settings
    )
  }
}

private struct TopBar: View {
  let onNew: () -> Void

  var body: some View {
    HStack {
      Button(action: onNew) {
        Label("Neu", systemImage: "plus")
      }
      .buttonStyle(.borderless)
      .keyboardShortcut("n", modifiers: .command)
      Spacer()
      Button {
        // Settings window: Phase 7
      } label: {
        Image(systemName: "gear")
      }
      .buttonStyle(.borderless)
    }
    .padding(12)
  }
}
