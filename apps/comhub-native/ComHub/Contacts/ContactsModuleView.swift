import SwiftUI
import AtollHub

/// Kombiniertes Adressbuch im CoHub-Look: links A-Z-Liste, rechts Detail.
struct ContactsModuleView: View {
  @Environment(Hub.self) private var hub
  @State private var store = ContactsStore()
  @State private var selection: String?

  private var selectedContact: MergedContact? {
    store.merged.first { $0.id == selection }
  }

  var body: some View {
    CompactWidthReader { compact in
      Group {
        if compact { compactBody } else { wideBody }
      }
      .task {
        await store.reload(using: hub)
        // Auf Wide eine Default-Auswahl setzen (rechte Spalte nicht leer).
        // Auf Kompakt NICHT vorauswaehlen, sonst pusht das Detail sofort.
        if !compact, selection == nil {
          selection = ContactSections.byLetter(store.filtered).first?.contacts.first?.id
        }
      }
    }
  }

  private var wideBody: some View {
    HStack(spacing: 0) {
      ContactListPane(store: store, selection: $selection)
        #if os(macOS)
        .frame(width: 330)
        #endif
      Divider()
      ContactDetailPane(contact: selectedContact)
        .frame(maxWidth: .infinity)
    }
  }

  private var compactBody: some View {
    NavigationStack {
      ContactListPane(store: store, selection: $selection)
        .navigationDestination(item: pushedContact) { contact in
          ContactDetailPane(contact: contact)
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
