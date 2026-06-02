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
    HStack(spacing: 0) {
      ContactListPane(store: store, selection: $selection)
        #if os(macOS)
        .frame(width: 330)
        #endif
      Divider()
      ContactDetailPane(contact: selectedContact)
        .frame(maxWidth: .infinity)
    }
    .task {
      await store.reload(using: hub)
      if selection == nil {
        selection = ContactSections.byLetter(store.filtered).first?.contacts.first?.id
      }
    }
  }
}
