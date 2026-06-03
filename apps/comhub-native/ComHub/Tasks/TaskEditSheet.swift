import SwiftUI
import EventKit
import AtollHub

/// Aufgabe erstellen/bearbeiten (Apple Erinnerung bzw. Atoll-Task). `existing == nil`
/// → Erstellen. Titel Pflicht; Faelligkeit + Liste optional.
struct TaskEditSheet: View {
  var existing: UnifiedTask? = nil
  let onSave: (_ title: String, _ due: Date?, _ listId: String?) async -> Bool
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
    CoSheetScaffold(
      icon: "checklist",
      tint: CoColor.accent,
      title: existing == nil ? "Neue Aufgabe" : "Aufgabe bearbeiten",
      canSave: !title.trimmingCharacters(in: .whitespaces).isEmpty,
      onSave: { await onSave(title, hasDue ? due : nil, listId) }
    ) {
      Section("Titel") {
        TextField("Titel", text: $title)
      }
      Section("Fälligkeit") {
        Toggle("Fällig", isOn: $hasDue)
        if hasDue { DatePicker("Datum", selection: $due, displayedComponents: [.date, .hourAndMinute]) }
      }
      if !lists.isEmpty && !isAtoll {
        Section("Liste") {
          Picker("Liste", selection: $listId) {
            Text("Standard").tag(String?.none)
            ForEach(lists, id: \.id) { l in Text(l.title).tag(Optional(l.id)) }
          }
        }
      }
    }
    .onAppear { prefill() }
  }

  private func prefill() {
    guard let t = existing else { return }
    title = t.title
    if let d = t.due { hasDue = true; due = d }
    // Liste nach Namen matchen (Apple).
    if let name = t.listName { listId = lists.first { $0.title == name }?.id }
  }
}
