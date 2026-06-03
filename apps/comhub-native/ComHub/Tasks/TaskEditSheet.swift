import SwiftUI
import EventKit
import AtollHub

/// Aufgabe erstellen/bearbeiten (Apple Erinnerung bzw. Atoll-Task). `existing == nil`
/// → Erstellen. Titel Pflicht; Faelligkeit + Liste optional.
struct TaskEditSheet: View {
  var existing: UnifiedTask? = nil
  let onSave: (_ title: String, _ due: Date?, _ listId: String?) -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var title = ""
  @State private var hasDue = false
  @State private var due = Date()
  @State private var listId: String?

  /// Atoll-Tasks haben kein Apple-Listen-Konzept → Picker nur fuer Apple zeigen.
  private var isAtoll: Bool { existing?.source.type == .atoll }

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
        if !lists.isEmpty && !isAtoll {
          Picker("Liste", selection: $listId) {
            Text("Standard").tag(String?.none)
            ForEach(lists, id: \.id) { l in Text(l.title).tag(Optional(l.id)) }
          }
        }
      }
      .navigationTitle(existing == nil ? "Neue Aufgabe" : "Aufgabe bearbeiten")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Sichern") { onSave(title, hasDue ? due : nil, listId); dismiss() }
            .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
        }
      }
      .onAppear(perform: prefill)
    }
    #if os(macOS)
    .frame(minWidth: 380, minHeight: 320)
    #endif
  }

  private func prefill() {
    guard let t = existing else { return }
    title = t.title
    if let d = t.due { hasDue = true; due = d }
    // Liste nach Namen matchen (Apple).
    if let name = t.listName { listId = lists.first { $0.title == name }?.id }
  }
}
