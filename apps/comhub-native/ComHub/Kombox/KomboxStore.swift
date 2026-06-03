import Foundation
import Observation
import AtollCore
import AtollHub
import Supabase
import OSLog

/// Lädt die Kombox (Konversationen + Verlauf) aus `contact_events` und hält
/// sie via Supabase-Realtime aktuell. Realtime folgt dem invalidate->refetch-
/// Muster: bei INSERT/UPDATE wird neu geladen (der Realtime-Payload traegt
/// keine `contacts`-Joins).
@MainActor
@Observable
final class KomboxStore {
  private(set) var conversations: [KomboxConversation] = []
  private(set) var thread: [KomboxDaySection] = []
  private(set) var loadingConversations = false
  private(set) var loadingThread = false
  var selectedContactId: String?

  var channel: KomboxChannel = .all
  var search: String = ""
  private(set) var sending = false
  private(set) var actionError: String?

  /// Gefilterte Konversationen (Kanal + Suche) — die Liste rendert diese.
  var visibleConversations: [KomboxConversation] {
    KomboxFilter.apply(conversations, channel: channel, search: search)
  }

  private let supabase = SupabaseClient.shared
  private let logger = Logger(subsystem: "swiss.atoll.hub", category: "kombox")
  private var realtimeTask: Task<Void, Never>?
  /// Generations-Token: verwirft veraltete Thread-Antworten (last-write-wins
  /// bei schnellem Konversationswechsel + langsamem Netz).
  private var threadGeneration = 0

  private var calendar: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
    c.firstWeekday = 2
    return c
  }

  private static let selectColumns =
    "id, contact_id, event_type, occurred_at, summary, body, payload, status, " +
    "contacts!inner(id, kind, first_name, last_name, trading_name, legal_name)"

  // MARK: - Laden

  func reloadConversations() async {
    loadingConversations = true
    do {
      let rows: [KomboxEventRow] = try await supabase
        .from("contact_events")
        .select(Self.selectColumns)
        .order("occurred_at", ascending: false)
        .limit(300)
        .execute()
        .value
      conversations = KomboxDigest.conversations(from: KomboxMapper.events(from: rows))
    } catch {
      logger.error("reloadConversations failed: \(error.localizedDescription, privacy: .public)")
    }
    loadingConversations = false
  }

  func selectContact(_ contactId: String) async {
    selectedContactId = contactId
    actionError = nil          // alte Fehlermeldung beim Konversationswechsel raeumen
    await reloadThread()
  }

  func clearSelection() {
    selectedContactId = nil
    actionError = nil
    thread = []
  }

  func reloadThread() async {
    guard let contactId = selectedContactId else { thread = []; return }
    threadGeneration += 1
    let gen = threadGeneration
    loadingThread = true
    do {
      let rows: [KomboxEventRow] = try await supabase
        .from("contact_events")
        .select(Self.selectColumns)
        .eq("contact_id", value: contactId)
        .order("occurred_at", ascending: true)
        .limit(500)
        .execute()
        .value
      // Veraltete Antwort verwerfen, wenn inzwischen ein neuerer Reload lief
      // (anderer Kontakt oder Realtime-Tick) — sonst falscher Verlauf.
      guard gen == threadGeneration else { return }
      thread = KomboxDigest.threadSections(KomboxMapper.events(from: rows), calendar: calendar)
    } catch {
      logger.error("reloadThread failed: \(error.localizedDescription, privacy: .public)")
    }
    if gen == threadGeneration { loadingThread = false }
  }

  // MARK: - Realtime (invalidate -> refetch)

  func startRealtime() {
    realtimeTask?.cancel()
    realtimeTask = Task { [weak self] in
      guard let self else { return }
      let channel = self.supabase.channel("public:contact_events:comhub")
      let inserts = channel.postgresChange(InsertAction.self, schema: "public", table: "contact_events")
      let updates = channel.postgresChange(UpdateAction.self, schema: "public", table: "contact_events")
      do { try await channel.subscribeWithError() }
      catch {
        self.logger.error("realtime subscribe failed: \(error.localizedDescription, privacy: .public)")
        return
      }
      await withTaskGroup(of: Void.self) { group in
        group.addTask { for await _ in inserts { await self.onRealtimeChange() } }
        group.addTask { for await _ in updates { await self.onRealtimeChange() } }
      }
    }
  }

  func stopRealtime() {
    realtimeTask?.cancel()
    realtimeTask = nil
  }

  private func onRealtimeChange() async {
    await reloadConversations()
    if selectedContactId != nil { await reloadThread() }
  }

  // MARK: - Senden / Loeschen

  private struct OutboundRequest: Encodable {
    let contactId: String
    let channel: String
    let body: String
    let subject: String?
    enum CodingKeys: String, CodingKey { case contactId = "contact_id"; case channel, body, subject }
  }
  private struct OutboundResponse: Decodable { let ok: Bool? }

  /// Sendet via Edge Function `comms-outbound`. `channel` = "whatsapp" | "email".
  func send(channel: String, body: String, subject: String?) async -> Bool {
    guard let contactId = selectedContactId else { return false }
    let text = body.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return false }
    sending = true; actionError = nil
    defer { sending = false }
    do {
      let req = OutboundRequest(contactId: contactId, channel: channel, body: text,
                                subject: (channel == "email") ? subject : nil)
      let _: OutboundResponse = try await supabase.functions.invoke(
        "comms-outbound", options: FunctionInvokeOptions(body: req))
      await reloadThread(); await reloadConversations()
      return true
    } catch {
      logger.error("send failed: \(error.localizedDescription, privacy: .public)")
      actionError = "Senden fehlgeschlagen (Konto verbunden?)"
      return false
    }
  }

  /// Loescht eine Nachricht (RLS: nur Owner). DELETE ist nicht im Realtime — manueller Refetch.
  func deleteEvent(id: String) async {
    actionError = nil
    do {
      try await supabase.from("contact_events").delete().eq("id", value: id).execute()
      await reloadThread(); await reloadConversations()
    } catch {
      logger.error("delete failed: \(error.localizedDescription, privacy: .public)")
      actionError = "Loeschen fehlgeschlagen."
    }
  }
}
