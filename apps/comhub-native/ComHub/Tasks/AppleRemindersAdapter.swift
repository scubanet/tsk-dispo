import Foundation
@preconcurrency import EventKit
import AtollHub

/// Erfuellt `TodoProvider` ueber Apple Erinnerungen (`EKReminder`). Lese-only.
/// Liste = `EKCalendar.title` (+ Farbe), Flag ~ hohe Prioritaet, isDone = completed.
struct AppleRemindersAdapter: TodoProvider {
  let accountId: String
  nonisolated(unsafe) private let store: EKEventStore

  init(accountId: String = "apple", store: EKEventStore) {
    self.accountId = accountId
    self.store = store
  }

  func tasks() async throws -> [UnifiedTask] {
    guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else { return [] }
    let predicate = store.predicateForReminders(in: nil)
    let ref = AccountRef(accountId: accountId, type: .apple)
    // Map EKReminder -> UnifiedTask inside the callback so only [UnifiedTask]
    // (Sendable) crosses the task-isolation boundary — avoids Swift 6 data-race error.
    let mapped: [UnifiedTask] = await withCheckedContinuation { (cont: CheckedContinuation<[UnifiedTask], Never>) in
      store.fetchReminders(matching: predicate) { reminders in
        let result = (reminders ?? []).map { r -> UnifiedTask in
          let due = r.dueDateComponents.flatMap { Calendar.current.date(from: $0) }
          let colorHex = r.calendar?.cgColor.flatMap(Self.hex(from:))
          return UnifiedTask(
            id: "apple:\(r.calendarItemIdentifier)",
            source: ref, title: r.title ?? "(Ohne Titel)",
            due: due, isDone: r.isCompleted,
            listName: r.calendar?.title, listColorHex: colorHex,
            isFlagged: r.priority != 0 && r.priority <= 3,
            priority: r.priority, notes: r.notes
          )
        }
        cont.resume(returning: result)
      }
    }
    return mapped
  }

  func setDone(taskId: String, isDone: Bool) async throws {
    let identifier = SourceID.raw(from: taskId)
    // 1) Schnellweg: direkter Lookup.
    if let item = store.calendarItem(withIdentifier: identifier) as? EKReminder {
      item.isCompleted = isDone               // setzt/entfernt completionDate automatisch
      try store.save(item, commit: true)
      return
    }
    // 2) Fallback: `calendarItem(withIdentifier:)` ist fuer EKReminder unzuverlaessig
    //    (liefert oft nil). Per Predicate holen + im Closure mutieren/speichern, damit
    //    kein nicht-Sendable EKReminder die Continuation-Grenze quert.
    let store = self.store
    let ok: Bool = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
      store.fetchReminders(matching: store.predicateForReminders(in: nil)) { reminders in
        guard let r = (reminders ?? []).first(where: { $0.calendarItemIdentifier == identifier }) else {
          cont.resume(returning: false); return
        }
        r.isCompleted = isDone
        do { try store.save(r, commit: true); cont.resume(returning: true) }
        catch { cont.resume(returning: false) }
      }
    }
    if !ok { throw ProviderWriteError.notFound }
  }

  func updateTask(id: String, title: String, due: Date?, listId: String?) async throws {
    let identifier = SourceID.raw(from: id)
    let store = self.store
    let dueComps = due.map { Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: $0) }
    let targetCal = listId.flatMap { store.calendar(withIdentifier: $0) }
    func apply(_ r: EKReminder) {
      r.title = title
      r.dueDateComponents = dueComps
      if let targetCal { r.calendar = targetCal }
    }
    if let item = store.calendarItem(withIdentifier: identifier) as? EKReminder {
      apply(item); try store.save(item, commit: true); return
    }
    let ok: Bool = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
      store.fetchReminders(matching: store.predicateForReminders(in: nil)) { reminders in
        guard let r = (reminders ?? []).first(where: { $0.calendarItemIdentifier == identifier }) else {
          cont.resume(returning: false); return
        }
        apply(r)
        do { try store.save(r, commit: true); cont.resume(returning: true) }
        catch { cont.resume(returning: false) }
      }
    }
    if !ok { throw ProviderWriteError.notFound }
  }

  func createTask(title: String, due: Date?, listId: String?) async throws {
    let reminder = EKReminder(eventStore: store)
    reminder.title = title
    if let listId, let cal = store.calendar(withIdentifier: listId) {
      reminder.calendar = cal
    } else {
      reminder.calendar = store.defaultCalendarForNewReminders()
    }
    if let due {
      reminder.dueDateComponents = Calendar.current.dateComponents(
        [.year, .month, .day, .hour, .minute], from: due)
    }
    try store.save(reminder, commit: true)
  }

  private static func hex(from cg: CGColor) -> String? {
    guard let c = cg.components, c.count >= 3 else { return nil }
    let r = Int((c[0] * 255).rounded()), g = Int((c[1] * 255).rounded()), b = Int((c[2] * 255).rounded())
    return String(format: "#%02X%02X%02X", r, g, b)
  }
}
