import SwiftUI
import EventKit

/// Neue Aufgabe (Apple Erinnerung). Titel Pflicht; Faelligkeit + Liste optional.
struct TaskEditSheet: View {
  let onSave: (_ title: String, _ due: Date?, _ listId: String?) -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var title = ""
  @State private var hasDue = false
  @State private var due = Date()
  @State private var listId: String?

  private let lists: [(id: String, title: String)] = {
    EKEventStore().calendars(for: .reminder).map { ($0.calendarIdentifier, $0.title) }
  }()

  var body: some View {
    NavigationStack {
      Form {
        TextField("Titel", text: $title)
        Section {
          Toggle("Fällig", isOn: $hasDue)
          if hasDue { DatePicker("Datum", selection: $due, displayedComponents: [.date, .hourAndMinute]) }
        }
        if !lists.isEmpty {
          Picker("Liste", selection: $listId) {
            Text("Standard").tag(String?.none)
            ForEach(lists, id: \.id) { l in Text(l.title).tag(Optional(l.id)) }
          }
        }
      }
      .navigationTitle("Neue Aufgabe")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Sichern") { onSave(title, hasDue ? due : nil, listId); dismiss() }
            .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
        }
      }
    }
    #if os(macOS)
    .frame(minWidth: 380, minHeight: 320)
    #endif
  }
}
