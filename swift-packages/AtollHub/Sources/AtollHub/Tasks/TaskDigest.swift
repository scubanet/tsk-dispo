import Foundation

/// Smart-Filter der Aufgaben-Rail.
public enum TaskSmartFilter: String, Sendable, CaseIterable, Identifiable {
  case all, today, flagged
  public var id: String { rawValue }
  public var title: String {
    switch self { case .all: return "Alle"; case .today: return "Heute"; case .flagged: return "Markiert" }
  }
}

/// Eine „Meine Listen"-Gruppe.
public struct TaskList: Sendable, Identifiable, Equatable {
  public let id: String
  public let name: String
  public let colorHex: String?
  public let openCount: Int
  public init(name: String, colorHex: String?, openCount: Int) {
    self.id = name; self.name = name; self.colorHex = colorHex; self.openCount = openCount
  }
}

/// Reine Filter-/Gruppier-Logik fuers Aufgaben-Modul.
public enum TaskDigest {
  public static func filter(_ tasks: [UnifiedTask], smart: TaskSmartFilter, list: String?,
                            now: Date, calendar: Calendar) -> (open: [UnifiedTask], done: [UnifiedTask]) {
    let today = calendar.startOfDay(for: now)
    var filtered = tasks
    switch smart {
    case .all:     break
    case .today:   filtered = filtered.filter { $0.due.map { calendar.startOfDay(for: $0) == today } ?? false }
    case .flagged: filtered = filtered.filter { $0.isFlagged }
    }
    if let list { filtered = filtered.filter { $0.listName == list } }

    let open = filtered.filter { !$0.isDone }.sorted { lhs, rhs in
      switch (lhs.due, rhs.due) {
      case let (l?, r?): return l < r
      case (nil, _?):    return false
      case (_?, nil):    return true
      case (nil, nil):   return lhs.title < rhs.title
      }
    }
    let done = filtered.filter { $0.isDone }.sorted { $0.title < $1.title }
    return (open, done)
  }

  public static func lists(_ tasks: [UnifiedTask]) -> [TaskList] {
    var color: [String: String?] = [:]
    var openCount: [String: Int] = [:]
    for t in tasks {
      guard let name = t.listName else { continue }
      if color[name] == nil { color[name] = t.listColorHex }
      if !t.isDone { openCount[name, default: 0] += 1 }
    }
    return color.keys.sorted().map {
      TaskList(name: $0, colorHex: color[$0] ?? nil, openCount: openCount[$0] ?? 0)
    }
  }
}
