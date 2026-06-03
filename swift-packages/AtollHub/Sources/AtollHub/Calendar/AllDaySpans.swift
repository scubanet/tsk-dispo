import Foundation

/// Layoutet ganztägige Events als durchgehende Balken über ein Tage-Fenster
/// (Tag/Woche). Mehrtägige Events ergeben EINEN Balken, der sich über die
/// betroffenen Spalten erstreckt (auf das Fenster geclippt). Nicht-überlappende
/// Events werden in dieselbe Reihe gepackt; überlappende in weitere Reihen.
public enum AllDaySpans {
  /// Ein Balken in der Ganztags-Lane: Start-Spaltenindex + Spaltenzahl (`span`).
  public struct Bar: Equatable, Identifiable, Sendable {
    public let event: UnifiedEvent
    public let startIndex: Int   // Spaltenindex in `days` (0-basiert, geclippt)
    public let span: Int         // Anzahl überdeckter Spalten (>= 1)
    public var id: String { event.id }
    public init(event: UnifiedEvent, startIndex: Int, span: Int) {
      self.event = event; self.startIndex = startIndex; self.span = span
    }
  }

  /// Reihen von Balken (Interval-Partitioning: pro Reihe keine Spalten-Überlappung).
  public static func layout(_ events: [UnifiedEvent], days: [Date],
                            calendar: Calendar) -> [[Bar]] {
    guard !days.isEmpty else { return [] }
    let starts = days.map { calendar.startOfDay(for: $0) }

    struct Span { let event: UnifiedEvent; let lo: Int; let hi: Int }
    var spans: [Span] = []
    for ev in events where ev.isAllDay {
      var lo: Int? = nil
      var hi = 0
      for (i, dayStart) in starts.enumerated() {
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        // Überlappung, wenn ev.start < dayEnd && ev.end > dayStart (end exklusiv).
        if ev.start < dayEnd && ev.end > dayStart {
          if lo == nil { lo = i }
          hi = i
        }
      }
      if let lo { spans.append(Span(event: ev, lo: lo, hi: hi)) }
    }

    // Stabile Reihenfolge: Startspalte, dann Startdatum, dann Titel.
    spans.sort { a, b in
      if a.lo != b.lo { return a.lo < b.lo }
      if a.event.start != b.event.start { return a.event.start < b.event.start }
      return a.event.title < b.event.title
    }

    var rows: [[Bar]] = []
    var rowEnds: [Int] = []     // letzter belegter Spaltenindex je Reihe
    for s in spans {
      let bar = Bar(event: s.event, startIndex: s.lo, span: s.hi - s.lo + 1)
      var placed = false
      for r in rows.indices where s.lo > rowEnds[r] {
        rows[r].append(bar); rowEnds[r] = s.hi; placed = true; break
      }
      if !placed { rows.append([bar]); rowEnds.append(s.hi) }
    }
    return rows
  }
}
