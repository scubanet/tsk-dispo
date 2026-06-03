import SwiftUI
import AtollHub

/// Thread-Liste: Kopf (Filter-Titel + Anzahl) + Suche + Konversations-Zeilen.
struct ConversationListView: View {
  let store: KomboxStore
  @Binding var selection: String?

  private static let time: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "dd.MM. HH:mm"
    f.locale = Locale(identifier: "de_CH")
    f.timeZone = TimeZone(identifier: "Europe/Zurich"); return f
  }()

  var body: some View {
    VStack(spacing: 0) {
      VStack(spacing: 10) {
        HStack {
          Text(store.channel.title).font(.system(size: 17, weight: .bold))
          Spacer()
          Text("\(store.visibleConversations.count)").font(.system(size: 12)).foregroundStyle(.tertiary)
        }
        searchField
      }
      .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 10)
      Divider()

      List(store.visibleConversations, selection: $selection) { conv in
        ConversationRow(conv: conv, timeText: Self.time.string(from: conv.lastEvent.timestamp))
          .tag(conv.id)
      }
      .overlay {
        if store.loadingConversations && store.conversations.isEmpty {
          ProgressView()
        } else if store.visibleConversations.isEmpty && !store.search.isEmpty {
          ContentUnavailableView("Keine Treffer", systemImage: "magnifyingglass")
        }
      }
    }
  }

  private var searchField: some View {
    HStack(spacing: 7) {
      Image(systemName: "magnifyingglass").font(.system(size: 13)).foregroundStyle(.tertiary)
      TextField("Suchen", text: Binding(get: { store.search }, set: { store.search = $0 }))
        .textFieldStyle(.plain).font(.system(size: 13))
    }
    .padding(.horizontal, 10).frame(height: 30)
    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
  }
}

/// Eine Konversations-Zeile: Avatar + Kanal-Dot, Name, Zeit, Vorschau.
private struct ConversationRow: View {
  let conv: KomboxConversation
  let timeText: String

  var body: some View {
    HStack(spacing: 10) {
      ZStack(alignment: .bottomTrailing) {
        CoAvatar(name: conv.contactName, size: 38)
        Image(systemName: channelIcon)
          .font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
          .frame(width: 15, height: 15).background(channelColor, in: Circle())
          .overlay(Circle().strokeBorder(.background, lineWidth: 1.5))
          .offset(x: 3, y: 3)
      }
      VStack(alignment: .leading, spacing: 1) {
        HStack {
          Text(conv.contactName).font(.system(size: 13.5, weight: .semibold)).lineLimit(1)
          Spacer(minLength: 0)
          Text(timeText).font(.system(size: 11)).foregroundStyle(.tertiary)
        }
        Text(preview).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
      }
    }
    .padding(.vertical, 3)
  }

  private var channelIcon: String {
    switch conv.lastEvent.kind { case .whatsapp: return "bubble.left.fill"; case .email: return "envelope.fill"; case .system: return "info" }
  }
  private var channelColor: Color {
    switch conv.lastEvent.kind { case .whatsapp: return CoColor.module(.kombox); case .email: return CoColor.accent; case .system: return .secondary }
  }
  private var preview: String {
    let e = conv.lastEvent
    let p = e.direction == .outbound ? "Du: " : ""
    return p + (e.kind == .email ? (e.subject ?? e.summary) : (e.body ?? e.summary))
  }
}
