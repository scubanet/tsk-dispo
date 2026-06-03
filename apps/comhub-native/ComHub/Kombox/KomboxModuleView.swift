import SwiftUI
import AtollHub

/// Kombox-Modul: Wide als 3-Pane (Kanal-Rail · Konversationsliste · Reader),
/// kompakt (iPhone) als Liste mit Kanal-Menue + Push auf den Reader. Laedt beim
/// Erscheinen und haelt via Realtime aktuell.
struct KomboxModuleView: View {
  @State private var store = KomboxStore()
  @State private var selection: String?

  var body: some View {
    CompactWidthReader { compact in
      Group {
        if compact { compactBody } else { wideBody }
      }
      .task {
        await store.reloadConversations()
        store.startRealtime()
      }
      .onDisappear { store.stopRealtime() }
      .onChange(of: selection) { _, new in
        if let new {
          Task { await store.selectContact(new) }
        } else {
          store.clearSelection()
        }
      }
    }
  }

  // MARK: Wide (macOS/iPad regular) — unveraendertes 3-Pane.

  private var wideBody: some View {
    @Bindable var store = store
    return HStack(spacing: 0) {
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
  }

  // MARK: Kompakt (iPhone) — Liste mit Kanal-Menue, Reader via Push.

  private var compactBody: some View {
    @Bindable var store = store
    return NavigationStack {
      ConversationListView(store: store, selection: $selection)
        .toolbar {
          ToolbarItem(placement: .automatic) {
            Menu {
              Picker("Kanal", selection: $store.channel) {
                ForEach(KomboxChannel.allCases) { ch in
                  Text(ch.title).tag(ch)
                }
              }
            } label: {
              Image(systemName: "line.3.horizontal.decrease.circle")
            }
          }
        }
        .navigationDestination(isPresented: pushedReader) {
          ThreadView(store: store)
        }
    }
  }

  /// Push genau dann, wenn eine Konversation gewaehlt ist. Beim Zurueck wird
  /// die Auswahl geleert (Liste wieder im Vordergrund). Der Reader liest seinen
  /// Inhalt aus `store.selectedContactId` (von `.onChange(of: selection)` gesetzt).
  private var pushedReader: Binding<Bool> {
    Binding(
      get: { selection != nil },
      set: { if !$0 { selection = nil } })
  }
}
