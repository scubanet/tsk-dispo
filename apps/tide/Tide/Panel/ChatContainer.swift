import SwiftUI
import Core

struct ChatContainer: View {
  @Bindable var viewModel: ChatViewModel

  var body: some View {
    VStack(spacing: 0) {
      MessageList(messages: viewModel.messages)
      Divider()
      HStack(spacing: 8) {
        TextField("Frag was…", text: $viewModel.input, axis: .vertical)
          .lineLimit(1...4)
          .textFieldStyle(.roundedBorder)
          .onSubmit {
            Task { await viewModel.send() }
          }
        Button {
          Task { await viewModel.send() }
        } label: {
          Image(systemName: "paperplane.fill")
        }
        .disabled(viewModel.input.isEmpty || viewModel.isStreaming)
      }
      .padding(10)
    }
  }
}
