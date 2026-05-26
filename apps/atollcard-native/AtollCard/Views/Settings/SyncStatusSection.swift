import SwiftUI

/// Settings-section that surfaces the offline-queue state to the user:
///   • Reachability dot (green online / yellow offline)
///   • Count of queued mutations waiting to flush
///   • Count of dead-lettered mutations — tappable to `DeadLetterView`
///
/// MVP scope: shows counts only. The pending-list isn't its own view yet —
/// once mutations succeed (or fail past the retry threshold) they leave the
/// active queue, so a dedicated browser would mostly be empty. The dead-
/// letter view IS justified because those entries persist until the user
/// retries or discards them.
struct SyncStatusSection: View {
  @Environment(CacheStore.self)        private var cache:   CacheStore?
  @Environment(ReachabilityMonitor.self) private var reach: ReachabilityMonitor

  var body: some View {
    Section("Synchronisation") {
      HStack {
        Circle()
          .fill(reach.isConnected ? .green : .yellow)
          .frame(width: 8, height: 8)
        Text(reach.isConnected ? "Online" : "Offline")
      }

      if let cache {
        let pending = cache.pendingCount()
        if pending > 0 {
          HStack {
            Image(systemName: "arrow.triangle.2.circlepath")
              .foregroundStyle(.orange)
            Text("\(pending) Aktion\(pending == 1 ? "" : "en") wartet")
          }
        }

        let dead = cache.deadLetters()
        if !dead.isEmpty {
          NavigationLink {
            DeadLetterView()
          } label: {
            HStack {
              Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
              Text("\(dead.count) fehlgeschlagen")
            }
          }
        }
      }
    }
  }
}
