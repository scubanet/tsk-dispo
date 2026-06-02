import SwiftUI
import AtollHub

/// Kombox-Modul: links Konversationen, rechts Verlauf. Laedt beim Erscheinen
/// und haelt via Realtime aktuell.
struct KomboxModuleView: View {
  @State private var store = KomboxStore()
  @State private var selection: String?

  var body: some View {
    HStack(spacing: 0) {
      ConversationListView(store: store, selection: $selection)
        #if os(macOS)
        .frame(minWidth: 260, maxWidth: 320)
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
