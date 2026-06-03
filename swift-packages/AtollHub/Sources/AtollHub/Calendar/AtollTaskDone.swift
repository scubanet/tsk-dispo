import Foundation

/// Reine Logik fuer das Erledigt-Umschalten eines Atoll-Tasks (`contact_events`).
/// Done → `status = "resolved"` + `completed_at` (ISO-8601); Undone → `status = "open"` + `nil`.
public enum AtollTaskDone {
  public struct Patch: Equatable, Sendable {
    public let status: String
    public let completedAt: String?
  }
  public static func patch(isDone: Bool, now: Date) -> Patch {
    guard isDone else { return Patch(status: "open", completedAt: nil) }
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime]
    return Patch(status: "resolved", completedAt: iso.string(from: now))
  }
}
