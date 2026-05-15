import SwiftUI
import EventKit
import AtollCore
import AtollDesign

struct EventDetailSheet: View {
  let event: CalendarEvent
  @Environment(\.dismiss) var dismiss

  var body: some View {
    NavigationStack {
      Form {
        Section {
          HStack {
            Rectangle().fill(event.color).frame(width: 4, height: 24)
            Text(event.title).font(.headline)
          }
          Text(formattedDateRange)
            .foregroundColor(.secondary)
            .font(.subheadline)
          if let loc = event.location, !loc.isEmpty {
            Label(loc, systemImage: "mappin.and.ellipse")
          }
        }

        switch event {
        case .system(let ek):
          Section("Kalender") {
            Text(ek.calendar?.title ?? "—")
          }
          if let notes = ek.notes, !notes.isEmpty {
            Section("Notizen") {
              Text(notes)
            }
          }
        case .atoll(let assignment, _):
          Section("ATOLL — Tauchkurs") {
            Label("Rolle: \(assignment.role.rawValue)", systemImage: "person.badge.shield.checkmark")
            if let course = assignment.course, let status = course.status {
              Label("Status: \(status.label)", systemImage: "checkmark.seal")
            }
            if assignment.confirmed {
              Label("Bestätigt", systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
            } else {
              Label("Nicht bestätigt", systemImage: "questionmark.circle")
                .foregroundColor(.orange)
            }
          }
          if let course = assignment.course, let notes = course.notes, !notes.isEmpty {
            Section("Notizen") {
              Text(notes)
            }
          }
        }
      }
      #if os(iOS)
      .navigationTitle(event.title)
      .navigationBarTitleDisplayMode(.inline)
      #else
      .navigationTitle(event.title)
      #endif
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Schließen") { dismiss() }
        }
      }
    }
  }

  private var formattedDateRange: String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "de_CH")
    f.dateStyle = .full
    f.timeStyle = event.isAllDay ? .none : .short
    if Calendar.current.isDate(event.startDate, inSameDayAs: event.endDate) {
      let dayStr = f.string(from: event.startDate)
      if event.isAllDay { return "\(dayStr) — ganztägig" }
      let timeF = DateFormatter()
      timeF.timeStyle = .short
      return "\(dayStr), \(timeF.string(from: event.startDate))–\(timeF.string(from: event.endDate))"
    } else {
      return "\(f.string(from: event.startDate)) — \(f.string(from: event.endDate))"
    }
  }
}
