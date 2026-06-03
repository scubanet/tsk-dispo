import Foundation

/// Ein Event mit zugewiesener Spalte fuers Tages-Zeitgitter (Ueberlapp-Layout).
public struct PositionedEvent: Sendable, Identifiable, Equatable {
  public let event: UnifiedEvent
  public let column: Int
  public let columnCount: Int
  public var id: String { event.id }
  public init(event: UnifiedEvent, column: Int, columnCount: Int) {
    self.event = event; self.column = column; self.columnCount = columnCount
  }
}

/// Spalten-Packing fuer ueberlappende timed Events (Mockup `packDay`):
/// Cluster sich ueberlappender Events teilen sich nebeneinanderliegende Spalten.
public enum EventColumns {
  public static func layout(_ events: [UnifiedEvent]) -> [PositionedEvent] {
    let timed = events.filter { !$0.isAllDay }.sorted { $0.start < $1.start }
    var out: [PositionedEvent] = []
    var cluster: [UnifiedEvent] = []
    var clusterEnd: Date = .distantPast

    func flush() {
      guard !cluster.isEmpty else { return }
      var colEnds: [Date] = []
      var assigned: [(UnifiedEvent, Int)] = []
      for ev in cluster {
        var placed = false
        for c in colEnds.indices where colEnds[c] <= ev.start {
          colEnds[c] = ev.end; assigned.append((ev, c)); placed = true; break
        }
        if !placed { colEnds.append(ev.end); assigned.append((ev, colEnds.count - 1)) }
      }
      let count = colEnds.count
      out += assigned.map { PositionedEvent(event: $0.0, column: $0.1, columnCount: count) }
      cluster = []
    }

    for ev in timed {
      if !cluster.isEmpty, ev.start < clusterEnd {
        cluster.append(ev); clusterEnd = max(clusterEnd, ev.end)
      } else {
        flush(); cluster = [ev]; clusterEnd = ev.end
      }
    }
    flush()
    return out.sorted { $0.event.start < $1.event.start }
  }
}
