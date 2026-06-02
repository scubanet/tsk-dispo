import SwiftUI
import AtollHub

/// Verlauf eines Kontakts: Tages-Sektionen mit Zeilen, neueste unten.
struct ThreadView: View {
  let store: KomboxStore

  private static let dayLabel: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "EEEE, d. MMMM"
    f.locale = Locale(identifier: "de_CH")
    f.timeZone = TimeZone(identifier: "Europe/Zurich"); return f
  }()

  var body: some View {
    Group {
      if store.selectedContactId == nil {
        ContentUnavailableView("Konversation wählen", systemImage: "bubble.left.and.bubble.right")
      } else if store.thread.isEmpty {
        ContentUnavailableView(store.loadingThread ? "Lädt…" : "Keine Nachrichten",
                               systemImage: "bubble.left")
      } else {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 10) {
            ForEach(store.thread) { section in
              HStack {
                Spacer()
                Text(Self.dayLabel.string(from: section.day))
                  .font(.caption2).foregroundStyle(.secondary)
                  .padding(.horizontal, 10).padding(.vertical, 3)
                  .background(.quaternary.opacity(0.4), in: Capsule())
                Spacer()
              }
              .padding(.top, 6)
              ForEach(section.events) { KomboxRow(event: $0) }
            }
          }
          .padding(12)
        }
      }
    }
  }
}
