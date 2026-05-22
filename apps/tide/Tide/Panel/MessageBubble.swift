import SwiftUI
import Core

struct MessageBubble: View {
  let message: Message

  var body: some View {
    HStack(alignment: .top) {
      if message.role == .user { Spacer(minLength: 40) }
      Text(message.content.isEmpty ? "…" : message.content)
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(
          message.role == .user
            ? Color.accentColor.opacity(0.15)
            : Color.gray.opacity(0.08)
        )
        .clipShape(.rect(cornerRadius: 10))
        .textSelection(.enabled)
      if message.role == .assistant { Spacer(minLength: 40) }
    }
    .padding(.horizontal, 12)
  }
}
