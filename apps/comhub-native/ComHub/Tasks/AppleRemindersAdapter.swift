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
    guard let item = store.calendarItem(withIdentifier: identifier) as? EKReminder else {
      throw ProviderWriteError.notFound
    }
    item.isCompleted = isDone               // setzt/entfernt completionDate automatisch
    try store.save(item, commit: true)
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
