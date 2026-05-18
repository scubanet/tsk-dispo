import SwiftUI
import EventKit
import AtollCore
import AtollDesign

/// Create / edit a system-calendar event, or show a read-only ATOLL info card.
///
/// Three entry points:
/// - `init(initialDate:)`     — create a new event, defaulting start to either
///                              the next round hour today or 09:00 on that day.
/// - `init(editing:)`         — edit an existing EKEvent. The repeat-rule and
///                              alarms picker pre-fill from the event.
/// - `init(readonlyAtoll:)`   — read-only ATOLL assignment view with a link to
///                              atoll.swiss, since ATOLL events live in the
///                              web app and aren't writable here.
struct EventEditorSheet: View {
  enum Mode {
    /// Create with a single seed date — snaps to next round hour or 09:00.
    case create(initialDate: Date)
    /// Create with explicit start + end (used by drag-to-create in DayView).
    case createInterval(DateInterval)
    case edit(EKEvent)
    case readonlyAtoll(Assignment)
  }

  let mode: Mode

  init(initialDate: Date) { self.mode = .create(initialDate: initialDate) }
  init(initialInterval: DateInterval) { self.mode = .createInterval(initialInterval) }
  init(editing event: EKEvent) { self.mode = .edit(event) }
  init(readonlyAtoll assignment: Assignment) { self.mode = .readonlyAtoll(assignment) }

  // MARK: - Env

  @Environment(\.dismiss) private var dismiss
  @Environment(\.openURL) private var openURL
  @Environment(SystemCalendarStore.self) private var calendarStore

  // MARK: - Form state

  @State private var title: String = ""
  @State private var selectedCalendarId: String?
  @State private var isAllDay: Bool = false
  @State private var startDate: Date = Date()
  @State private var endDate: Date = Date().addingTimeInterval(3600)
  @State private var location: String = ""
  @State private var notes: String = ""
  @State private var repeatRule: RepeatRule = .none
  @State private var alarm: AlarmKind = .none

  @State private var saveError: String?

  enum RepeatRule: String, CaseIterable, Identifiable {
    case none, daily, weekly, monthly, yearly
    var id: String { rawValue }
    var label: String {
      switch self {
      case .none:    return "Nie"
      case .daily:   return "Täglich"
      case .weekly:  return "Wöchentlich"
      case .monthly: return "Monatlich"
      case .yearly:  return "Jährlich"
      }
    }
    var ekFrequency: EKRecurrenceFrequency? {
      switch self {
      case .none:    return nil
      case .daily:   return .daily
      case .weekly:  return .weekly
      case .monthly: return .monthly
      case .yearly:  return .yearly
      }
    }
  }

  enum AlarmKind: String, CaseIterable, Identifiable {
    case none, atStart, fiveMin, fifteenMin, oneHour, oneDay
    var id: String { rawValue }
    var label: String {
      switch self {
      case .none:       return "Keine"
      case .atStart:    return "Beim Start"
      case .fiveMin:    return "5 Min vorher"
      case .fifteenMin: return "15 Min vorher"
      case .oneHour:    return "1 Stunde vorher"
      case .oneDay:     return "1 Tag vorher"
      }
    }
    var relativeOffset: TimeInterval? {
      switch self {
      case .none:       return nil
      case .atStart:    return 0
      case .fiveMin:    return -300
      case .fifteenMin: return -900
      case .oneHour:    return -3600
      case .oneDay:     return -86400
      }
    }
  }

  // MARK: - Body

  var body: some View {
    NavigationStack {
      Group {
        switch mode {
        case .readonlyAtoll(let assignment):
          atollReadonly(assignment: assignment)
        case .create, .createInterval, .edit:
          editForm
        }
      }
    }
    .presentationDetents([.large])
    .presentationBackground(.thinMaterial)
    .onAppear(perform: populateFromMode)
  }

  // MARK: - ATOLL read-only mode

  @ViewBuilder
  private func atollReadonly(assignment: Assignment) -> some View {
    Form {
      Section {
        Label(assignment.course?.title ?? "ATOLL-Einsatz", systemImage: "stethoscope")
          .font(.headline)
        Label("Rolle: \(assignment.role.rawValue)", systemImage: "person.fill")
        if let status = assignment.course?.status {
          Label("Status: \(status.label)", systemImage: "checkmark.seal")
        }
      }
      Section {
        Text("ATOLL-Einsätze werden im Web verwaltet. Öffne deinen Plan in der ATOLL-Web-App, um Anpassungen vorzunehmen.")
          .font(.callout)
          .foregroundStyle(.secondary)
        Button {
          if let url = URL(string: "https://atoll.swiss") { openURL(url) }
        } label: {
          Label("Auf atoll.swiss öffnen", systemImage: "arrow.up.right.square")
        }
      }
    }
    .navigationTitle("ATOLL-Einsatz")
    #if os(iOS)
    .navigationBarTitleDisplayMode(.inline)
    #endif
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Schließen") { dismiss() }
      }
    }
  }

  // MARK: - Edit / create form

  @ViewBuilder
  private var editForm: some View {
    Form {
      Section {
        TextField("Titel", text: $title)
          .textFieldStyle(.plain)
        if !calendarStore.writableCalendars.isEmpty {
          Picker("Kalender", selection: Binding(
            get: { selectedCalendarId ?? calendarStore.writableCalendars.first?.calendarIdentifier },
            set: { selectedCalendarId = $0 }
          )) {
            ForEach(calendarStore.writableCalendars, id: \.calendarIdentifier) { cal in
              HStack {
                Circle().fill(Color(cgColor: cal.cgColor)).frame(width: 10, height: 10)
                Text(cal.title)
              }
              .tag(Optional(cal.calendarIdentifier))
            }
          }
        } else {
          Text("Kein bearbeitbarer Kalender vorhanden.")
            .foregroundStyle(.secondary)
            .font(.caption)
        }
      }

      Section {
        Toggle("Ganztägig", isOn: $isAllDay.animation(.snappy))
        DatePicker("Start",
                   selection: $startDate,
                   displayedComponents: isAllDay ? .date : [.date, .hourAndMinute])
        DatePicker("Ende",
                   selection: $endDate,
                   in: startDate...,
                   displayedComponents: isAllDay ? .date : [.date, .hourAndMinute])
      }

      Section {
        TextField("Ort", text: $location)
        TextField("Notizen", text: $notes, axis: .vertical)
          .lineLimit(3...8)
      }

      Section {
        Picker("Wiederholung", selection: $repeatRule) {
          ForEach(RepeatRule.allCases) { Text($0.label).tag($0) }
        }
        Picker("Erinnerung", selection: $alarm) {
          ForEach(AlarmKind.allCases) { Text($0.label).tag($0) }
        }
      }

      if case .edit(let event) = mode, event.calendar?.allowsContentModifications ?? false {
        Section {
          Button(role: .destructive) {
            deleteEvent(event)
          } label: {
            Label("Termin löschen", systemImage: "trash")
          }
        }
      }

      if let err = saveError {
        Section {
          Label(err, systemImage: "exclamationmark.triangle")
            .foregroundStyle(.red)
            .font(.caption)
        }
      }
    }
    .navigationTitle(navigationTitle)
    #if os(iOS)
    .navigationBarTitleDisplayMode(.inline)
    #endif
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Abbrechen") { dismiss() }
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("Speichern") { save() }
          .disabled(saveDisabled)
      }
    }
    .onChange(of: startDate) { _, newStart in
      if endDate <= newStart {
        endDate = newStart.addingTimeInterval(3600)
      }
    }
    .onChange(of: isAllDay) { _, allDay in
      // Snap to start-of-day / end-of-day when switching to all-day
      let cal = Calendar.current
      if allDay {
        startDate = cal.startOfDay(for: startDate)
        endDate = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: endDate)) ?? endDate
      }
    }
  }

  private var saveDisabled: Bool {
    title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || endDate < startDate
      || selectedCalendarId == nil
  }

  private var navigationTitle: String {
    if case .edit = mode { return "Termin bearbeiten" }
    return "Neuer Termin"
  }

  // MARK: - Populate

  private func populateFromMode() {
    switch mode {
    case .create(let initialDate):
      let cal = Calendar.current
      let referenceDay = cal.startOfDay(for: initialDate)
      let start: Date
      if cal.isDateInToday(initialDate) {
        // Next round hour from now (capped at 22:00 to avoid wrap)
        let h = min(cal.component(.hour, from: Date()) + 1, 22)
        start = cal.date(bySettingHour: h, minute: 0, second: 0, of: referenceDay) ?? referenceDay
      } else {
        start = cal.date(bySettingHour: 9, minute: 0, second: 0, of: referenceDay) ?? referenceDay
      }
      startDate = start
      endDate = start.addingTimeInterval(3600)
      selectedCalendarId = calendarStore.writableCalendars.first?.calendarIdentifier

    case .createInterval(let interval):
      // Drag-to-create: honour both edges literally.
      startDate = interval.start
      endDate = interval.end
      selectedCalendarId = calendarStore.writableCalendars.first?.calendarIdentifier

    case .edit(let event):
      title = event.title ?? ""
      isAllDay = event.isAllDay
      startDate = event.startDate
      endDate = event.endDate
      location = event.location ?? ""
      notes = event.notes ?? ""
      selectedCalendarId = event.calendar?.calendarIdentifier

      if let rule = event.recurrenceRules?.first {
        switch rule.frequency {
        case .daily:   repeatRule = .daily
        case .weekly:  repeatRule = .weekly
        case .monthly: repeatRule = .monthly
        case .yearly:  repeatRule = .yearly
        @unknown default: repeatRule = .none
        }
      }
      if let firstAlarm = event.alarms?.first {
        switch firstAlarm.relativeOffset {
        case 0:      alarm = .atStart
        case -300:   alarm = .fiveMin
        case -900:   alarm = .fifteenMin
        case -3600:  alarm = .oneHour
        case -86400: alarm = .oneDay
        default:     alarm = .none
        }
      }

    case .readonlyAtoll:
      break
    }
  }

  // MARK: - Save / Delete

  private func save() {
    guard let calId = selectedCalendarId,
          let ekCal = calendarStore.writableCalendars.first(where: { $0.calendarIdentifier == calId }) else {
      saveError = "Bitte einen Kalender wählen."
      return
    }

    let event: EKEvent
    switch mode {
    case .create, .createInterval:
      event = calendarStore.makeNewEvent()
    case .edit(let existing):
      event = existing
    case .readonlyAtoll:
      return
    }

    event.calendar = ekCal
    event.title = title
    event.isAllDay = isAllDay
    event.startDate = startDate
    event.endDate = endDate
    event.location = location.isEmpty ? nil : location
    event.notes = notes.isEmpty ? nil : notes

    // Recurrence — replace entire list rather than append.
    event.recurrenceRules = nil
    if let freq = repeatRule.ekFrequency {
      let rule = EKRecurrenceRule(recurrenceWith: freq, interval: 1, end: nil)
      event.addRecurrenceRule(rule)
    }

    // Alarms — replace entire list.
    event.alarms = nil
    if let offset = alarm.relativeOffset {
      event.addAlarm(EKAlarm(relativeOffset: offset))
    }

    do {
      try calendarStore.save(event)
      dismiss()
    } catch {
      saveError = "Speichern fehlgeschlagen: \(error.localizedDescription)"
    }
  }

  private func deleteEvent(_ event: EKEvent) {
    do {
      try calendarStore.remove(event)
      dismiss()
    } catch {
      saveError = "Löschen fehlgeschlagen: \(error.localizedDescription)"
    }
  }
}
