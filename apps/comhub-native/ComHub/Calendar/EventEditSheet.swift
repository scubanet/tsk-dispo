import SwiftUI
import AtollHub

/// Erstellen/Bearbeiten eines Apple-Termins. `existing == nil` → Erstellen.
struct EventEditSheet: View {
  let existing: UnifiedEvent?
  let sources: CalendarSourcesStore?
  let onSave: (EventDraft) -> Void
  let onDelete: (() -> Void)?
  @Environment(\.dismiss) private var dismiss

  @State private var title = ""
  @State private var start = Date()
  @State private var end = Date().addingTimeInterval(3600)
  @State private var isAllDay = false
  @State private var location = ""
  @State private var calendarId: String?

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("Titel", text: $title)
          Toggle("Ganztägig", isOn: $isAllDay)
          DatePicker("Beginn", selection: $start)
          DatePicker("Ende", selection: $end)
          TextField("Ort", text: $location)
        }
        if let appleSources = sources?.sources.filter({ $0.id != "atoll" }), !appleSources.isEmpty {
          Section("Kalender") {
            Picker("Kalender", selection: $calendarId) {
              ForEach(appleSources) { s in Text(s.title).tag(Optional(s.id)) }
            }
          }
        }
        if let onDelete {
          Section {
            Button("Termin löschen", role: .destructive) { onDelete(); dismiss() }
          }
        }
      }
      .navigationTitle(existing == nil ? "Neuer Termin" : "Termin bearbeiten")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Sichern") {
            onSave(EventDraft(title: title, start: start, end: end, isAllDay: isAllDay,
                              location: location.isEmpty ? nil : location, calendarId: calendarId))
            dismiss()
          }.disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || end <= start)
        }
      }
      .onAppear {
        if let e = existing {
          title = e.title; start = e.start; end = e.end
          isAllDay = e.isAllDay; location = e.location ?? ""; calendarId = e.calendarId
        }
      }
    }
    #if os(macOS)
    .frame(minWidth: 420, minHeight: 420)
    #endif
  }
}
