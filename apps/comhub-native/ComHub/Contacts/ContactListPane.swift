import SwiftUI
import AtollHub

/// Linke Spalte: Header („Kontakte" + Anzahl), Suchfeld, A-Z-Sektionen.
struct ContactListPane: View {
  let store: ContactsStore
  @Binding var selection: String?

  private var sections: [ContactLetterSection] {
    ContactSections.byLetter(store.filtered)
  }

  var body: some View {
    VStack(spacing: 0) {
      VStack(spacing: 10) {
        HStack {
          Text("Kontakte").font(.system(size: 17, weight: .bold))
          Spacer()
          Text("\(store.filtered.count)").font(.system(size: 12)).foregroundStyle(.tertiary)
        }
        searchField
      }
      .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 10)
      Divider()

      ScrollView {
        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
          ForEach(sections) { section in
            Section {
              ForEach(section.contacts) { contact in
                ContactRow(contact: contact, selected: selection == contact.id)
                  .onTapGesture { selection = contact.id }
                Divider()
              }
            } header: {
              Text(section.letter)
                .font(.system(size: 11, weight: .bold)).foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14).padding(.vertical, 3)
                .background(.bar)
            }
          }
        }
      }
    }
  }

  private var searchField: some View {
    HStack(spacing: 7) {
      Image(systemName: "magnifyingglass").font(.system(size: 13)).foregroundStyle(.tertiary)
      TextField("Kontakte suchen", text: Binding(
        get: { store.search }, set: { store.search = $0 }))
        .textFieldStyle(.plain)
        .font(.system(size: 13))
    }
    .padding(.horizontal, 10).frame(height: 30)
    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
  }
}
