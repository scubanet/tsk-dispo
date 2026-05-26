import Foundation
import WidgetKit
import OSLog

/// Writes the default-card snapshot into the App Group container and
/// triggers a Widget timeline reload.
///
/// All writes are atomic (`.atomic` option). Missing-snapshot → file
/// removal, never empty file (Widget code uses `Data(contentsOf:)` which
/// fails on empty file).
///
/// Reload is best-effort — `WidgetCenter.reloadAllTimelines()` is rate-
/// limited by iOS; calling it more often than ~once per minute may not
/// trigger an actual re-render but never errors.
enum SharedCardSnapshotWriter {
  private static let fileName = "default-card.json"
  private static let logger = Logger(subsystem: "swiss.atoll.card",
                                     category: "snapshot-writer")

  static func write(_ snapshot: SharedCardSnapshot?) {
    guard let container = FileManager.default
      .containerURL(forSecurityApplicationGroupIdentifier: Config.appGroupID) else {
      logger.error("App Group container missing for \(Config.appGroupID, privacy: .public)")
      return
    }
    let url = container.appendingPathComponent(fileName)

    if let snapshot {
      do {
        let data = try SharedCardSnapshot.encoder.encode(snapshot)
        try data.write(to: url, options: .atomic)
        logger.debug("Wrote snapshot for slug \(snapshot.slug, privacy: .public)")
      } catch {
        logger.error("Snapshot write failed: \(error.localizedDescription, privacy: .public)")
      }
    } else {
      try? FileManager.default.removeItem(at: url)
      logger.debug("Cleared snapshot file")
    }

    WidgetCenter.shared.reloadAllTimelines()
  }
}
