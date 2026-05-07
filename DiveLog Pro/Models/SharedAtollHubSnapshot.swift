import Foundation

/// Snapshot written by Atoll Hub, read by DiveLog Pro. Carries only the
/// fields Atoll Hub owns (display name, handle, avatar) so DiveLog can
/// mirror them in its own UI if it wants to. v1 of the bridge does not
/// surface this in the UI yet.
public struct SharedAtollHubSnapshot: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public let appleUserId: String
    public let displayName: String
    public let handle: String?
    public let avatarFileName: String?
    public let snapshotUpdatedAt: Date

    public nonisolated init(
        schemaVersion: Int = 1,
        appleUserId: String,
        displayName: String,
        handle: String?,
        avatarFileName: String?,
        snapshotUpdatedAt: Date
    ) {
        self.schemaVersion = schemaVersion
        self.appleUserId = appleUserId
        self.displayName = displayName
        self.handle = handle
        self.avatarFileName = avatarFileName
        self.snapshotUpdatedAt = snapshotUpdatedAt
    }
}

// Convenience JSONEncoder + JSONDecoder configured the same way both
// sides agree on. These MUST match Atoll Hub's helpers byte-for-byte.
// Scoped to the Atoll Hub bridge wire format — do not repurpose.
public extension JSONDecoder {
    nonisolated static func atollBridge() -> JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }
}

// Scoped to the Atoll Hub bridge wire format — do not repurpose.
public extension JSONEncoder {
    nonisolated static func atollBridge() -> JSONEncoder {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }
}
