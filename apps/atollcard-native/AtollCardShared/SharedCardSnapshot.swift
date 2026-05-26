import Foundation

/// Snapshot of the default card, shared between the AtollCard app and
/// the AtollCardWidget extension via the App Group container.
///
/// Source: written by `SharedCardSnapshotWriter` in the main app whenever
/// the default card changes.
/// Sink: read by `CardSnapshotProvider` in the Widget extension on every
/// timeline refresh.
///
/// The struct intentionally carries only what the Lock-Screen Widget needs
/// to render — no avatar URLs, no dive profile, no analytics. Keep it small
/// to avoid stale-data confusion when the source card gets richer.
public struct SharedCardSnapshot: Codable, Sendable, Equatable {
  public let slug:           String     // "dominik-cd"
  public let title:          String     // "PADI Course Director"
  public let badge:          String?    // "PADI CD" — nil if no badge set
  public let personInitials: String     // "DW"
  public let publicURL:      URL        // https://atoll-os.com/c/dominik-cd
  public let updatedAt:      Date       // when this snapshot was written

  public init(slug: String, title: String, badge: String?,
              personInitials: String, publicURL: URL, updatedAt: Date) {
    self.slug = slug
    self.title = title
    self.badge = badge
    self.personInitials = personInitials
    self.publicURL = publicURL
    self.updatedAt = updatedAt
  }
}

public extension SharedCardSnapshot {
  /// Standard ISO-8601 encoder used in both app and widget so dates roundtrip
  /// without timezone drift.
  static let encoder: JSONEncoder = {
    let e = JSONEncoder()
    e.dateEncodingStrategy = .iso8601
    return e
  }()

  /// Matching decoder.
  static let decoder: JSONDecoder = {
    let d = JSONDecoder()
    d.dateDecodingStrategy = .iso8601
    return d
  }()
}
