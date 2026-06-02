import Foundation

/// Kanal-Filter der Kombox-Kontaktliste.
public enum KomboxChannel: String, Sendable, CaseIterable, Identifiable {
  case all, whatsapp, mail
  public var id: String { rawValue }
  public var title: String {
    switch self { case .all: return "Alle"; case .whatsapp: return "WhatsApp"; case .mail: return "Mail" }
  }
}

/// Reine Filter-Logik: Kanal (nach letztem Event) + Volltextsuche (Name/Vorschau).
public enum KomboxFilter {
  public static func apply(_ conversations: [KomboxConversation],
                           channel: KomboxChannel, search: String) -> [KomboxConversation] {
    let q = search.trimmingCharacters(in: .whitespaces).lowercased()
    return conversations.filter { c in
      switch channel {
      case .all:      break
      case .whatsapp: if c.lastEvent.kind != .whatsapp { return false }
      case .mail:     if c.lastEvent.kind != .email { return false }
      }
      guard !q.isEmpty else { return true }
      let hay = (c.contactName + " " + (c.lastEvent.subject ?? "")
                 + " " + (c.lastEvent.body ?? c.lastEvent.summary)).lowercased()
      return hay.contains(q)
    }
  }
}
