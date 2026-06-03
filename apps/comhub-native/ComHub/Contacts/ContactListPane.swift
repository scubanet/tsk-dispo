import SwiftUI
import AtollHub

/// Linke Spalte: Header („Kontakte" + Anzahl), Suchfeld, A-Z-Sektionen.
struct ContactListPane: View {
  let store: ContactsStore
  @Binding var selection: String?
  /// Tippen auf „+" → neuen Kontakt erfassen.
  var onAdd: (() -> Void)? = nil

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
          if let onAdd {
            Button(action: onAdd) {
              Image(systemName: "plus")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(CoColor.accent)
                .frame(width: 30, height: 30)
                .background(
                  Circle().fill(CoColor.accent.opacity(0.12)).frame(width: 26, height: 26)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Neuer Kontakt")
          }
        }
        searchField
      }
      .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 10)
      Divider()

      if store.loading && sections.isEmpty {
        CoSkeletonRows()
          .frame(maxHeight: .infinity, alignment: .top)
      } else {
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
