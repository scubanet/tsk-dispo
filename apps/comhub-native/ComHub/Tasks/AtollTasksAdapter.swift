import Foundation
import AtollCore
import AtollHub
import Supabase

/// Erfuellt `TodoProvider` ueber Atoll-`contact_events` mit `event_type = "task"`.
/// `due` aus `payload.due_date`; `isDone` = Status nicht „open" oder `completed_at` gesetzt.
struct AtollTasksAdapter: TodoProvider {
  let accountId: String
  private let supabase = SupabaseClient.shared

  init(accountId: String = "atoll") { self.accountId = accountId }

  private struct TaskRow: Decodable {
    let id: String
    let summary: String
    let body: String?
    let status: String
    let payload: TaskPayload?
    struct TaskPayload: Decodable {
      let dueDate: String?
      let completedAt: String?
      enum CodingKeys: String, CodingKey { case dueDate = "due_date"; case completedAt = "completed_at" }
    }
  }

  func tasks() async throws -> [UnifiedTask] {
    let rows: [TaskRow] = try await supabase
      .from("contact_events")
      .select("id, summary, body, status, payload")
      .eq("event_type", value: "task")
      .order("occurred_at", ascending: false)
      .limit(500)
      .execute()
      .value
    let ref = AccountRef(accountId: accountId, type: .atoll)
    return rows.map { row in
      let done = row.status != "open" || (row.payload?.completedAt != nil)
      let due = row.payload?.dueDate.flatMap(Self.parseDate)
      return UnifiedTask(id: "atoll:\(row.id)", source: ref, title: row.summary,
                         due: due, isDone: done, notes: row.body)
    }
  }

  /// Schreibt den Erledigt-Status zurueck nach `contact_events`.
  /// Aktualisiert nur `status` (open/resolved); die Done-Erkennung in `tasks()`
  /// liest `status != "open"`, daher ist ein Status-Update ausreichend und konsistent.
  func setDone(taskId: String, isDone: Bool) async throws {
    let rowId = SourceID.raw(from: taskId)
    let patch = AtollTaskDone.patch(isDone: isDone, now: Date())

    // Bestehenden payload lesen, damit due_date u. a. erhalten bleiben.
    struct PayloadRow: Decodable { let payload: [String: AnyJSON]? }
    let existing: [PayloadRow] = try await supabase
      .from("contact_events")
      .select("payload")
      .eq("id", value: rowId)
      .limit(1)
      .execute()
      .value
    var payload = existing.first?.payload ?? [:]
    if let completedAt = patch.completedAt {
      payload["completed_at"] = .string(completedAt)
    } else {
      payload["completed_at"] = nil          // Key entfernen
    }

    struct TaskUpdate: Encodable { let status: String; let payload: [String: AnyJSON] }
    _ = try await supabase
      .from("contact_events")
      .update(TaskUpdate(status: patch.status, payload: payload))
      .eq("id", value: rowId)
      .execute()
  }

  /// Aendert Titel (`summary`) + Faelligkeit (`payload.due_date`). Liste wird bei
  /// Atoll-Tasks ignoriert (kein Listen-Konzept).
  func updateTask(id: String, title: String, due: Date?, listId: String?) async throws {
    let rowId = SourceID.raw(from: id)
    struct PayloadRow: Decodable { let payload: [String: AnyJSON]? }
    let existing: [PayloadRow] = try await supabase
      .from("contact_events").select("payload").eq("id", value: rowId).limit(1).execute().value
    var payload = existing.first?.payload ?? [:]
    if let due {
      let f = DateFormatter()
      f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX")
      f.timeZone = TimeZone(identifier: "Europe/Zurich"); f.dateFormat = "yyyy-MM-dd"
      payload["due_date"] = .string(f.string(from: due))
    } else {
      payload["due_date"] = nil
    }
    struct TaskPatch: Encodable { let summary: String; let payload: [String: AnyJSON] }
    _ = try await supabase
      .from("contact_events").update(TaskPatch(summary: title, payload: payload))
      .eq("id", value: rowId).execute()
  }

  private static func parseDate(_ s: String) -> Date? {
    let dayOnly = DateFormatter()
    dayOnly.dateFormat = "yyyy-MM-dd"; dayOnly.locale = Locale(identifier: "en_US_POSIX")
    dayOnly.timeZone = TimeZone(identifier: "Europe/Zurich")
    if let d = dayOnly.date(from: s) { return d }
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime]
    return iso.date(from: s)
  }
}
