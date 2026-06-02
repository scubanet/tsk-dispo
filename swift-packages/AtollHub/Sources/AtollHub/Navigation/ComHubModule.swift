/// Die Module der linken Leiste, in Anzeigereihenfolge. `systemImage` sind
/// SF-Symbol-Namen (UI-neutral als String gehalten, damit der Kern
/// SwiftUI-frei bleibt und testbar ist).
public enum ComHubModule: String, Sendable, CaseIterable, Identifiable {
  case heute
  case kalender
  case kombox
  case kontakte
  case tasks
  case cardInbox
  case einstellungen

  public var id: String { rawValue }

  public var title: String {
    switch self {
    case .heute:         return "Heute"
    case .kalender:      return "Kalender"
    case .kombox:        return "Kombox"
    case .kontakte:      return "Kontakte"
    case .tasks:         return "Aufgaben"
    case .cardInbox:     return "CardInbox"
    case .einstellungen: return "Einstellungen"
    }
  }

  public var systemImage: String {
    switch self {
    case .heute:         return "house"
    case .kalender:      return "calendar"
    case .kombox:        return "bubble.left.and.bubble.right"
    case .kontakte:      return "person.2"
    case .tasks:         return "checklist"
    case .cardInbox:     return "tray.and.arrow.down"
    case .einstellungen: return "gearshape"
    }
  }
}
