import SwiftUI
import AtollHub

/// Kontaktliste: Konversationen (letzte Nachricht je Kontakt, neueste zuerst).
struct ConversationListView: View {
  let store: KomboxStore
  @Binding var selection: String?

  private static let time: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "dd.MM. HH:mm"
    f.locale = Locale(identifier: "de_CH")
    f.timeZone = TimeZone(identifier: "Europe/Zurich"); return f
  }()

  var body: some View {
    List(store.conversations, selection: $selection) { conv in
      VStack(alignment: .leading, spacing: 2) {
        HStack {
          Image(systemName: icon(conv.lastEvent.kind))
            .font(.caption).foregroundStyle(.secondary)
          Text(conv.contactName).font(.callout.weight(.medium)).lineLimit(1)
          Spacer(minLength: 0)
          Text(Self.time.string(from: conv.lastEvent.timestamp))
            .font(.caption2).foregroundStyle(.secondary)
        }
        Text(preview(conv.lastEvent)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
      }
      .tag(conv.id)
      .padding(.vertical, 2)
    }
    .overlay { if store.loadingConversations && store.conversations.isEmpty { ProgressView() } }
  }

  private func icon(_ kind: KomboxKind) -> String {
    switch kind {
    case .whatsapp: return "bubble.left.fill"
    case .email:    return "envelope.fill"
    case .system:   return "info.circle"
    }
  }
  private func preview(_ e: KomboxEvent) -> String {
    let prefix = e.direction == .outbound ? "Du: " : ""
    return prefix + (e.kind == .email ? (e.subject ?? e.summary) : (e.body ?? e.summary))
  }
}
