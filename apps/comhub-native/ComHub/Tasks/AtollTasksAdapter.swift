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
    let status = isDone ? "resolved" : "open"
    _ = try await supabase
      .from("contact_events")
      .update(["status": status])
      .eq("id", value: rowId)
      .execute()
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
