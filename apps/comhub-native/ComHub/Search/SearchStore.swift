import Foundation
import Observation
import AtollHub

/// Ein Treffer der globalen Suche — quellneutral ueber alle drei Module.
enum SearchHit: Identifiable {
  case contact(MergedContact, score: Int)
  case event(UnifiedEvent, score: Int)
  case task(UnifiedTask, score: Int)

  var id: String {
    switch self {
    case .contact(let c, _): return "contact:\(c.id)"
    case .event(let e, _):   return "event:\(e.id)"
    case .task(let t, _):    return "task:\(t.id)"
    }
  }

  var score: Int {
    switch self {
    case .contact(_, let s), .event(_, let s), .task(_, let s): return s
    }
  }
}

/// Globale Suche: laedt EINMAL einen Korpus (Kontakte/Termine/Aufgaben) und
/// bewertet dann rein synchron pro Tastendruck ueber `SearchRank` (kein Netz).
@MainActor
@Observable
final class SearchStore {
  var query: String = ""
  private(set) var loading = false
  private(set) var ready = false

  private var contacts: [MergedContact] = []
  private var events: [UnifiedEvent] = []
  private var tasks: [UnifiedTask] = []

  /// Zurich-Kalender fuer das Event-Fenster (now +/- 180 Tage).
  private var calendar: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
    return c
  }()

  private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
  private var hasQuery: Bool { !trimmedQuery.isEmpty }

  /// Holt den Korpus einmal (Kontakte gematcht wie im Kontakte-Modul, Termine
  /// in einem weiten Fenster, Aufgaben komplett). Idempotent ueber `ready`.
  func reload(using hub: Hub) async {
    guard !ready, !loading else { return }
    loading = true

    let raw = await hub.allContacts()
    contacts = ContactMatcher.group(raw).map(MergedContact.init(group:))

    let now = Date()
    let from = calendar.date(byAdding: .day, value: -180, to: now) ?? now
    let to = calendar.date(byAdding: .day, value: 180, to: now) ?? now
    events = await hub.allEvents(in: DateInterval(start: from, end: to))

    tasks = await hub.allTasks()

    ready = true
    loading = false
  }

  // MARK: - Gruppen-Zugriffe (gefiltert + sortiert, gedeckelt)

  private static let cap = 20

  var contactHits: [SearchHit] {
    guard hasQuery else { return [] }
    let q = trimmedQuery
    return contacts.compactMap { c -> SearchHit? in
      let fields: [String?] = [c.displayName, c.firstName, c.lastName, c.organizationName]
        + c.emails.map { Optional($0) } + c.phones.map { Optional($0) }
      guard let s = SearchRank.best(fields, query: q) else { return nil }
      return .contact(c, score: s)
    }
    .sorted { lhs, rhs in
      guard case .contact(let lc, let ls) = lhs, case .contact(let rc, let rs) = rhs else { return false }
      if ls != rs { return ls > rs }
      return lc.displayName.localizedCaseInsensitiveCompare(rc.displayName) == .orderedAscending
    }
    .prefix(Self.cap).map { $0 }
  }

  var eventHits: [SearchHit] {
    guard hasQuery else { return [] }
    let q = trimmedQuery
    return events.compactMap { e -> SearchHit? in
      guard let s = SearchRank.best([e.title, e.location], query: q) else { return nil }
      return .event(e, score: s)
    }
    .sorted { lhs, rhs in
      guard case .event(let le, let ls) = lhs, case .event(let re, let rs) = rhs else { return false }
      if ls != rs { return ls > rs }
      return le.start < re.start
    }
    .prefix(Self.cap).map { $0 }
  }

  var taskHits: [SearchHit] {
    guard hasQuery else { return [] }
    let q = trimmedQuery
    return tasks.compactMap { t -> SearchHit? in
      guard let s = SearchRank.best([t.title, t.notes, t.listName], query: q) else { return nil }
      return .task(t, score: s)
    }
    .sorted { lhs, rhs in
      guard case .task(let lt, let ls) = lhs, case .task(let rt, let rs) = rhs else { return false }
      if ls != rs { return ls > rs }
      return lt.title.localizedCaseInsensitiveCompare(rt.title) == .orderedAscending
    }
    .prefix(Self.cap).map { $0 }
  }

  /// Alle Treffer (fuer Leer-Status-Erkennung).
  var hasAnyHit: Bool { !contactHits.isEmpty || !eventHits.isEmpty || !taskHits.isEmpty }
}
