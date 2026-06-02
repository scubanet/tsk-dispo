import SwiftUI
import AtollHub

/// Kombox-Modul (3-Pane): Kanal-Rail · Konversationsliste · Reader. Laedt beim
/// Erscheinen und haelt via Realtime aktuell.
struct KomboxModuleView: View {
  @State private var store = KomboxStore()
  @State private var selection: String?

  var body: some View {
    @Bindable var store = store
    HStack(spacing: 0) {
      KomboxRailView(channel: $store.channel)
        #if os(macOS)
        .frame(width: 180)
        #endif
      Divider()
      ConversationListView(store: store, selection: $selection)
        #if os(macOS)
        .frame(width: 320)
        #endif
      Divider()
      ThreadView(store: store)
        .frame(maxWidth: .infinity)
    }
    .task {
      await store.reloadConversations()
      store.startRealtime()
    }
    .onDisappear { store.stopRealtime() }
    .onChange(of: selection) { _, new in
      guard let new else { return }
      Task { await store.selectContact(new) }
    }
  }
}
