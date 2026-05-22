import SwiftUI
import Core

struct MessageList: View {
  let messages: [Message]

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(spacing: 8) {
          ForEach(messages) { msg in
            MessageBubble(message: msg).id(msg.id)
          }
        }
        .padding(.vertical, 12)
      }
      .onChange(of: messages.last?.content) { _, _ in
        if let last = messages.last {
          withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
        }
      }
    }
  }
}
