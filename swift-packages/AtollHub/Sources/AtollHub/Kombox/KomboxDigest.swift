import Foundation

/// Reine Aggregations-Helfer fuer die Kombox.
public enum KomboxDigest {
  /// Neuestes Event je Kontakt → Konversationen, neueste zuerst.
  public static func conversations(from events: [KomboxEvent]) -> [KomboxConversation] {
    var latest: [String: KomboxEvent] = [:]
    for e in events {
      if let cur = latest[e.contactId] {
        if e.timestamp > cur.timestamp { latest[e.contactId] = e }
      } else {
        latest[e.contactId] = e
      }
    }
    return latest.values
      .sorted { $0.timestamp > $1.timestamp }
      .map { KomboxConversation(id: $0.contactId, contactName: $0.contactName, lastEvent: $0) }
  }

  /// Events eines Verlaufs nach Tag gruppiert (Sektionen aufsteigend,
  /// Events innerhalb aufsteigend nach Zeit) — fuer Tages-Trenner.
  public static func threadSections(_ events: [KomboxEvent],
                                    calendar: Calendar) -> [KomboxDaySection] {
    var byDay: [Date: [KomboxEvent]] = [:]
    for e in events {
      let day = calendar.startOfDay(for: e.timestamp)
      byDay[day, default: []].append(e)
    }
    return byDay.keys.sorted().map { day in
      KomboxDaySection(day: day,
                       events: byDay[day]!.sorted { $0.timestamp < $1.timestamp })
    }
  }
}
