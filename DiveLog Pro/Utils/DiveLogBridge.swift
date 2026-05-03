import Foundation
import os

/// Read/write the App Group snapshot exchange between DiveLog Pro and
/// Atoll Hub. `containerURL` defaults to the production App Group
/// container; future tests can inject a temp directory.
public actor DiveLogBridge {
    public static let appGroupId = "group.com.atollhub.shared"
    public static let diveLogSnapshotFile = "dive-log-snapshot.json"
    public static let atollHubSnapshotFile = "atoll-hub-snapshot.json"

    private static let logger = Logger(
        subsystem: "com.weckherlin.DiveLogPro",
        category: "AtollBridge"
    )

    private let containerURL: URL?

    public init(containerURL: URL? = nil) {
        self.containerURL = containerURL ?? FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupId)
        if self.containerURL == nil {
            Self.logger.error("App Group container unavailable — entitlement missing or not provisioned")
        }
    }

    public var hasContainer: Bool { containerURL != nil }

    /// Atomic write of the DiveLog snapshot. Throws only on encoder/IO
    /// failure; silent no-op when the container is unavailable so the
    /// caller doesn't have to special-case unprovisioned simulator runs.
    public func writeDiveLogSnapshot(_ snapshot: SharedDiveLogSnapshot) throws {
        guard let url = diveLogSnapshotURL else {
            Self.logger.warning("writeDiveLogSnapshot skipped — no container")
            return
        }
        let data = try JSONEncoder.atollBridge().encode(snapshot)
        try data.write(to: url, options: .atomic)
        Self.logger.info("wrote dive-log-snapshot.json (\(data.count) bytes)")
    }

    /// Read Atoll Hub's snapshot. Returns nil if the container is
    /// unavailable, the file doesn't exist, or it fails to decode.
    public func readAtollHubSnapshot() -> SharedAtollHubSnapshot? {
        guard let url = atollHubSnapshotURL else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try JSONDecoder.atollBridge().decode(SharedAtollHubSnapshot.self, from: data)
        } catch {
            Self.logger.error("failed to decode atoll-hub-snapshot.json: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Paths

    private var diveLogSnapshotURL: URL? {
        containerURL?.appending(component: Self.diveLogSnapshotFile)
    }

    private var atollHubSnapshotURL: URL? {
        containerURL?.appending(component: Self.atollHubSnapshotFile)
    }
}
