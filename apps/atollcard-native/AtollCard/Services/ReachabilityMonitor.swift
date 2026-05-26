import Foundation
import Network
import Observation
import OSLog

/// Lightweight `NWPathMonitor` wrapper exposed as an `@Observable` so SwiftUI
/// views (and the `MutationDrainer` trigger logic in `AtollCardApp`) can
/// react to connectivity edges.
///
/// `MainActor`-bound: `isConnected` mutations need to happen on the same actor
/// the SwiftUI runtime observes, so we hop back from the `NWPathMonitor`'s
/// background dispatch queue in the update handler.
@MainActor
@Observable
final class ReachabilityMonitor {
  /// Last known connectivity state. Optimistic-default `true` so the first
  /// frame doesn't render the offline banner before the monitor fires its
  /// initial event.
  private(set) var isConnected: Bool = true

  private let monitor = NWPathMonitor()
  private let queue   = DispatchQueue(label: "swiss.atoll.card.reachability")
  private static let logger = Logger(subsystem: "swiss.atoll.card", category: "reachability")

  init() {}

  /// Begin observing path updates. Idempotent re-calls are a no-op because
  /// `NWPathMonitor.start(queue:)` only takes effect the first time.
  func start() {
    monitor.pathUpdateHandler = { [weak self] path in
      Task { @MainActor [weak self] in
        let newValue = (path.status == .satisfied)
        if self?.isConnected != newValue {
          Self.logger.debug("Reachability: \(newValue ? "online" : "offline", privacy: .public)")
        }
        self?.isConnected = newValue
      }
    }
    monitor.start(queue: queue)
  }

  deinit { monitor.cancel() }
}
