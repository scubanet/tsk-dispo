import Foundation
import Observation
import AtollCore
import AtollHub
import Supabase

/// Aggregiert die Heute-Cockpit-Daten ueber den `Hub`: heutige Termine (live)
/// und offene Aufgaben (ueber `Hub.allTasks()`, leer bis Phase 4 einen
/// TodoProvider verdrahtet). Nachrichten/Leads kommen in Phase 3/4 dazu.
@MainActor
@Observable
final class CockpitStore {
  private(set) var todayEvents: [UnifiedEvent] = []
  private(set) var openTasks: [UnifiedTask] = []
  private(set) var recentConversations: [KomboxConversation] = []
  private(set) var loading = false
  private(set) var errors: [String] = []

  private static let komboxSelect =
    "id, contact_id, event_type, occurred_at, summary, body, payload, status, " +
    "contacts!inner(id, kind, first_name, last_name, trading_name, legal_name)"

  /// Zuerich-Kalender, konsistent mit den uebrigen ComHub-Datumshelfern.
  private var calendar: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
    c.firstWeekday = 2
    return c
  }

  func reload(using hub: Hub) async {
    loading = true
    let now = Date()
    let start = calendar.startOfDay(for: now)
    let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
    let interval = DateInterval(start: start, end: end)

    let events = await hub.allEvents(in: interval)
    let eventErrors = hub.lastErrors        // sichern: allTasks() setzt lastErrors zurueck
    let tasks = await hub.allTasks()

    todayEvents = CockpitDigest.todayEvents(from: events, now: now, calendar: calendar)
    openTasks = CockpitDigest.openTasks(from: tasks, limit: 8)
    errors = eventErrors + hub.lastErrors
    await reloadRecentConversations()
    loading = false
  }

  /// Juengste Kombox-Konversationen fuers Heute-Widget (gleiche Abfrage wie KomboxStore).
  func reloadRecentConversations(using supabase: SupabaseClient = .shared) async {
    do {
      let rows: [KomboxEventRow] = try await supabase
        .from("contact_events")
        .select(Self.komboxSelect)
        .order("occurred_at", ascending: false)
        .limit(100)
        .execute()
        .value
      recentConversations = Array(
        KomboxDigest.conversations(from: KomboxMapper.events(from: rows)).prefix(3)
      )
    } catch {
      // leise — das Widget zeigt sonst Empty-State
    }
  }
}
