import Foundation
import Observation
import OSLog

@MainActor
@Observable
public final class AnalyticsStore {
  public private(set) var current: CardAnalytics?
  public private(set) var lastError: Error?
  public var range: DateRangeOption = .thirtyDays
  public var scope: Scope = .aggregate

  public enum Scope: Equatable {
    case aggregate
    case card(UUID)
  }

  private let repository: AnalyticsRepository
  private static let logger = Logger(subsystem: "swiss.atoll.card", category: "analytics")

  public init(repository: AnalyticsRepository) {
    self.repository = repository
  }

  public func refresh() async {
    do {
      switch scope {
      case .aggregate:
        current = try await repository.fetchAggregateAnalytics(range: range)
      case .card(let id):
        current = try await repository.fetchAnalytics(cardId: id, range: range)
      }
      lastError = nil
    } catch {
      Self.logger.error("analytics refresh failed: \(error.localizedDescription, privacy: .public)")
      lastError = error
    }
  }
}
