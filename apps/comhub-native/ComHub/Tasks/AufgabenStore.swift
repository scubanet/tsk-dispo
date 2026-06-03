import Foundation
import Observation
import EventKit
import AtollHub

/// Lade-Zustand fuers Aufgaben-Modul: alle Tasks via Hub, Smart/Listen-Filter.
@MainActor
@Observable
final class AufgabenStore {
  private(set) var all: [UnifiedTask] = []
  private(set) var loading = false
  private(set) var lastError: String?
  var smart: TaskSmartFilter = .all
  var list: String?

  private var calendar: Calendar {
    var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
    c.firstWeekday = 2; return c
  }

  var lists: [TaskList] { TaskDigest.lists(all) }
  var result: (open: [UnifiedTask], done: [UnifiedTask]) {
    TaskDigest.filter(all, smart: list == nil ? smart : .all, list: list, now: Date(), calendar: calendar)
  }

  /// Offene-Anzahl je Smart-Filter — nutzt denselben Kalender wie `result`
  /// (sonst koennte „Heute" in der Rail vom Listen-Inhalt abweichen).
  func smartOpenCount(_ smart: TaskSmartFilter) -> Int {
    TaskDigest.filter(all, smart: smart, list: nil, now: Date(), calendar: calendar).open.count
  }

  private nonisolated(unsafe) var changeObserver: NSObjectProtocol?

  /// Reagiert auf System-Aenderungen (EventKit/Erinnerungen) und laedt neu. Idempotent.
  func startObservingChanges(using hub: Hub) {
    guard changeObserver == nil else { return }
    changeObserver = NotificationCenter.default.addObserver(
      forName: .EKEventStoreChanged, object: nil, queue: .main
    ) { [weak self] _ in
      Task { @MainActor in await self?.reload(using: hub) }
    }
  }

  deinit {
    if let changeObserver { NotificationCenter.default.removeObserver(changeObserver) }
  }

  func reload(using hub: Hub) async {
    loading = true
    all = await hub.allTasks()
    loading = false
  }

  /// Legt eine neue Aufgabe ueber den Hub an (Apple Erinnerung), dann neu laden.
  @discardableResult
  func create(title: String, due: Date?, listId: String?, using hub: Hub) async -> Bool {
    lastError = nil
    do { try await hub.createTask(title: title, due: due, listId: listId); await reload(using: hub); return true }
    catch { lastError = "Erstellen fehlgeschlagen: \(error)"; return false }
  }

  /// Aendert eine bestehende Aufgabe (Titel/Faelligkeit/Liste), dann neu laden.
  @discardableResult
  func update(id: String, title: String, due: Date?, listId: String?, using hub: Hub) async -> Bool {
    lastError = nil
    do { try await hub.updateTask(id: id, title: title, due: due, listId: listId); await reload(using: hub); return true }
    catch { lastError = "Aendern fehlgeschlagen: \(error)"; return false }
  }

  /// Schaltet Erledigt optimistisch um, schreibt ueber den Hub, laedt danach neu
  /// (autoritativ). Fehler werden sichtbar gemacht.
  func toggleDone(_ task: UnifiedTask, using hub: Hub) async {
    let target = !task.isDone
    lastError = nil
    if let i = all.firstIndex(where: { $0.id == task.id }) {
      all[i] = all[i].withDone(target)
    }
    do {
      try await hub.setTaskDone(task, done: target)
    } catch {
      lastError = "Abhaken fehlgeschlagen: \(error)"
    }
    await reload(using: hub)
  }
}
