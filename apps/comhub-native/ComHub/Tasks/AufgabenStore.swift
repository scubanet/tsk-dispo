import Foundation
import Observation
import AtollHub

/// Lade-Zustand fuers Aufgaben-Modul: alle Tasks via Hub, Smart/Listen-Filter.
@MainActor
@Observable
final class AufgabenStore {
  private(set) var all: [UnifiedTask] = []
  private(set) var loading = false
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

  func reload(using hub: Hub) async {
    loading = true
    all = await hub.allTasks()
    loading = false
  }
}
