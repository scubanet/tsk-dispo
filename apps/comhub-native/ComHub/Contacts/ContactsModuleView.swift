import SwiftUI
import AtollHub

/// Kombiniertes Adressbuch: Liste (mit Suche) + Detail mit Quell-Tags.
struct ContactsModuleView: View {
  @Environment(Hub.self) private var hub
  @State private var store = ContactsStore()
  @State private var selection: MergedContact?

  var body: some View {
    @Bindable var store = store
    List(store.filtered, selection: $selection) { contact in
      NavigationLink(value: contact) {
        VStack(alignment: .leading, spacing: 2) {
          Text(contact.displayName).font(.callout.weight(.medium))
          HStack(spacing: 4) {
            ForEach(contact.sources, id: \.self) { src in
              Text(src == .atoll ? "Atoll" : "Apple")
                .font(.caption2).foregroundStyle(.secondary)
                .padding(.horizontal, 5).padding(.vertical, 1)
                .background(.quaternary, in: Capsule())
            }
            if let mail = contact.emails.first {
              Text(mail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
          }
        }
      }
    }
    .searchable(text: $store.search, prompt: "Kontakte suchen")
    .overlay { if store.loading { ProgressView() } }
    .navigationDestination(for: MergedContact.self) { ContactDetailView(contact: $0) }
    .task { await store.reload(using: hub) }
  }
}

/// Detailansicht eines zusammengefuehrten Kontakts.
private struct ContactDetailView: View {
  let contact: MergedContact

  var body: some View {
    Form {
      Section {
        Text(contact.displayName).font(.title2.weight(.semibold))
        HStack(spacing: 6) {
          ForEach(contact.sources, id: \.self) { src in
            Label(src == .atoll ? "Atoll" : "Apple",
                  systemImage: src == .atoll ? "cloud" : "applelogo")
              .font(.caption)
          }
        }
      }
      if !contact.emails.isEmpty {
        Section("E-Mail") {
          ForEach(contact.emails, id: \.self) { Text($0).textSelection(.enabled) }
        }
      }
      if !contact.phones.isEmpty {
        Section("Telefon") {
          ForEach(contact.phones, id: \.self) { Text($0).textSelection(.enabled) }
        }
      }
    }
    .navigationTitle(contact.displayName)
  }
}
