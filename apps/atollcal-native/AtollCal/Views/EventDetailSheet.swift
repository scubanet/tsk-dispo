import SwiftUI
import EventKit
import AtollCore
import AtollDesign

/// Read-only detail card for either a system EKEvent or an ATOLL assignment.
///
/// System events that live in a writable calendar get Edit + Delete affordances
/// in the toolbar; everything else stays read-only.
struct EventDetailSheet: View {
  let event: CalendarEvent
  @Environment(\.dismiss) var dismiss
  @Environment(\.locale) var locale
  @Environment(SystemCalendarStore.self) private var calendarStore

  @State private var showingEditor: Bool = false
  @State private var showingDeleteConfirm: Bool = false
  @State private var deleteError: String?

  var body: some View {
    NavigationStack {
      Form {
        Section {
          HStack {
            Rectangle().fill(event.color).frame(width: 4, height: 24)
              .clipShape(.capsule)
            Text(event.title).font(.headline)
          }
          Text(formattedDateRange)
            .foregroundStyle(.secondary)
            .font(.subheadline)
          if let loc = event.location, !loc.isEmpty {
            Label(loc, systemImage: "mappin.and.ellipse")
          }
        }

        switch event {
        case .system(let ek):
          Section("Kalender") {
            HStack(spacing: 8) {
              if let cg = ek.calendar?.cgColor {
                Circle().fill(Color(cgColor: cg)).frame(width: 10, height: 10)
              }
              Text(ek.calendar?.title ?? "—")
            }
          }
          if let notes = ek.notes, !notes.isEmpty {
            Section("Notizen") { Text(notes) }
          }
        case .atoll(let assignment, _, let module):
          Section("ATOLL — Tauchkurs") {
            Label("Rolle: \(assignment.role.rawValue)", systemImage: "person.badge.shield.checkmark")
            if let course = assignment.course, let status = course.status {
              Label("Status: \(status.label)", systemImage: "checkmark.seal")
            }
            if assignment.confirmed {
              Label("Bestätigt", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
            } else {
              Label("Nicht bestätigt", systemImage: "questionmark.circle")
                .foregroundStyle(.orange)
            }
          }
          if let module {
            Section("Modul") {
              Label(module.type.label, systemImage: module.type.systemImage)
              Label(moduleTimeRange(module), systemImage: "clock")
              if module.type == .pool, let location = module.location, !location.isEmpty {
                Label("Pool: \(location)", systemImage: "mappin")
                if let reserved = module.reserved {
                  Label(
                    reserved ? "Slot bestätigt" : "Slot nicht bestätigt",
                    systemImage: reserved ? "checkmark.seal.fill" : "questionmark.diamond"
                  )
                  .foregroundStyle(reserved ? .green : .orange)
                }
              }
            }
          }
          if let course = assignment.course, let notes = course.notes, !notes.isEmpty {
            Section("Notizen") { Text(notes) }
          }
        }

        if let err = deleteError {
          Section {
            Label(err, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
              .font(.caption)
          }
        }
      }
      .navigationTitle(event.title)
      #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar { detailToolbar }
      .sheet(isPresented: $showingEditor) {
        editorSheet
      }
      .confirmationDialog(
        "Termin wirklich löschen?",
        isPresented: $showingDeleteConfirm,
        titleVisibility: .visible
      ) {
        Button("Löschen", role: .destructive) { performDelete() }
        Button("Abbrechen", role: .cancel) {}
      }
    }
    .presentationBackground(.thinMaterial)
  }

  // MARK: - Toolbar

  @ToolbarContentBuilder
  private var detailToolbar: some ToolbarContent {
    if case .system(let ek) = event, ek.calendar?.allowsContentModifications ?? false {
      ToolbarItem(placement: .destructiveAction) {
        Button(role: .destructive) {
          showingDeleteConfirm = true
        } label: {
          Image(systemName: "trash")
        }
      }
      ToolbarItem(placement: .primaryAction) {
        Button("Bearbeiten") { showingEditor = true }
      }
    }
    ToolbarItem(placement: .confirmationAction) {
      Button("Schließen") { dismiss() }
    }
  }

  @ViewBuilder
  private var editorSheet: some View {
    switch event {
    case .system(let ek):
      EventEditorSheet(editing: ek)
    case .atoll(let assignment, _, _):
      EventEditorSheet(readonlyAtoll: assignment)
    }
  }

  // MARK: - Helpers

  private func performDelete() {
    guard case .system(let ek) = event else { return }
    do {
      try calendarStore.remove(ek)
      dismiss()
    } catch {
      deleteError = "Löschen fehlgeschlagen: \(error.localizedDescription)"
    }
  }

  /// Formats `module.start`–`module.end` as `HH:MM–HH:MM` in the user's
  /// locale. Module times are wall-clock in `Europe/Zurich` per AtollCore.
  private func moduleTimeRange(_ module: CourseModule) -> String {
    let f = DateFormatter()
    f.locale = locale
    f.timeStyle = .short
    f.dateStyle = .none
    return "\(f.string(from: module.start))–\(f.string(from: module.end))"
  }

  private var formattedDateRange: String {
    let f = DateFormatter()
    f.locale = locale
    f.dateStyle = .full
    f.timeStyle = event.isAllDay ? .none : .short
    if Calendar.current.isDate(event.startDate, inSameDayAs: event.endDate) {
      let dayStr = f.string(from: event.startDate)
      if event.isAllDay { return "\(dayStr) — ganztägig" }
      let timeF = DateFormatter()
      timeF.locale = locale
      timeF.timeStyle = .short
      return "\(dayStr), \(timeF.string(from: event.startDate))–\(timeF.string(from: event.endDate))"
    } else {
      return "\(f.string(from: event.startDate)) — \(f.string(from: event.endDate))"
    }
  }
}
