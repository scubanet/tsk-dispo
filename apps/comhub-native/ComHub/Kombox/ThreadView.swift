import SwiftUI
import AtollHub

/// Reader: Kopf (Kontakt) + Tages-Verlauf (Bubbles/Mail/System) + Composer.
/// Pro Nachricht „Loeschen" via Kontextmenue.
struct ThreadView: View {
  let store: KomboxStore

  private static let dayLabel: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "EEEE, d. MMMM"
    f.locale = Locale(identifier: "de_CH")
    f.timeZone = TimeZone(identifier: "Europe/Zurich"); return f
  }()

  private var contactName: String {
    store.thread.flatMap(\.events).first?.contactName
      ?? store.conversations.first { $0.id == store.selectedContactId }?.contactName ?? ""
  }

  var body: some View {
    if store.selectedContactId == nil {
      ContentUnavailableView("Konversation wählen", systemImage: "bubble.left.and.bubble.right")
    } else {
      VStack(spacing: 0) {
        header
        Divider()
        messages
        Divider()
        KomboxComposer(store: store)
      }
    }
  }

  private var header: some View {
    HStack(spacing: 11) {
      CoAvatar(name: contactName, size: 30)
      Text(contactName).font(.system(size: 14, weight: .semibold)).lineLimit(1)
      Spacer()
    }
    .padding(.horizontal, 16).frame(height: 52)
  }

  @ViewBuilder
  private var messages: some View {
    if store.thread.isEmpty {
      ContentUnavailableView(store.loadingThread ? "Lädt…" : "Keine Nachrichten", systemImage: "bubble.left")
    } else {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 10) {
          ForEach(store.thread) { section in
            HStack {
              Spacer()
              Text(Self.dayLabel.string(from: section.day))
                .font(.system(size: 11)).foregroundStyle(.secondary)
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(.quaternary.opacity(0.4), in: Capsule())
              Spacer()
            }
            .padding(.top, 6)
            ForEach(section.events) { event in
              KomboxRow(event: event)
                .contextMenu {
                  Button("Löschen", role: .destructive) {
                    Task { await store.deleteEvent(id: event.id) }
                  }
                }
            }
          }
        }
        .padding(12)
      }
    }
  }
}
