import SwiftUI
import AtollHub

/// Kombiniertes Adressbuch im CoHub-Look: links A-Z-Liste, rechts Detail.
struct ContactsModuleView: View {
  @Environment(Hub.self) private var hub
  @State private var store = ContactsStore()
  @State private var selection: String?
  @State private var editing: MergedContact?
  @State private var deleting: MergedContact?
  @State private var showCreate = false

  private var selectedContact: MergedContact? {
    store.merged.first { $0.id == selection }
  }

  var body: some View {
    CompactWidthReader { compact in
      Group {
        if compact { compactBody } else { wideBody }
      }
      .task {
        store.startObservingChanges(using: hub)
        await store.reload(using: hub)
        // Auf Wide eine Default-Auswahl setzen (rechte Spalte nicht leer).
        // Auf Kompakt NICHT vorauswaehlen, sonst pusht das Detail sofort.
        if !compact, selection == nil {
          selection = ContactSections.byLetter(store.filtered).first?.contacts.first?.id
        }
      }
      .sheet(isPresented: $showCreate) {
        ContactEditSheet(existing: nil) { draft, src in
          await store.create(draft, source: src, using: hub)
        }
      }
      .sheet(item: $editing) { c in
        ContactEditSheet(existing: c) { draft, _ in
          let memberId = (c.members.first { $0.source.type == .atoll } ?? c.members.first)?.id ?? c.id
          return await store.update(id: memberId, with: draft, using: hub)
        }
      }
      .confirmationDialog(
        "Kontakt löschen?",
        isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
        presenting: deleting
      ) { c in
        Button("Löschen", role: .destructive) {
          let memberId = (c.members.first { $0.source.type == .atoll } ?? c.members.first)?.id ?? c.id
          Task {
            _ = await store.delete(id: memberId, using: hub)
            selection = nil
          }
        }
        Button("Abbrechen", role: .cancel) { }
      } message: { c in
        Text("\(c.displayName) wird " + ((c.members.first { $0.source.type == .atoll } != nil) ? "archiviert." : "aus den Apple-Kontakten gelöscht."))
      }
    }
  }

  private var wideBody: some View {
    HStack(spacing: 0) {
      ContactListPane(store: store, selection: $selection, onAdd: { showCreate = true })
        #if os(macOS)
        .frame(width: 330)
        #endif
      Divider()
      ContactDetailPane(contact: selectedContact,
                        onEdit: selectedContact.map { c in { editing = c } },
                        onDelete: selectedContact.map { c in { deleting = c } })
        .frame(maxWidth: .infinity)
    }
  }

  private var compactBody: some View {
    NavigationStack {
      ContactListPane(store: store, selection: $selection, onAdd: { showCreate = true })
        .navigationDestination(item: pushedContact) { contact in
          ContactDetailPane(contact: contact,
                            onEdit: { editing = contact },
                            onDelete: { deleting = contact })
        }
    }
  }

  /// Bindet die id-basierte `selection` an einen optionalen `MergedContact`,
  /// damit `navigationDestination(item:)` (Push) auf Kompakt funktioniert.
  private var pushedContact: Binding<MergedContact?> {
    Binding(
      get: { selectedContact },
      set: { selection = $0?.id })
  }
}
