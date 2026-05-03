import Foundation

/// Snapshot written by DiveLog Pro into the App Group container, read by
/// Atoll Hub. Schema-versioned for forward-compat. Keys match Atoll Hub's
/// `SharedDiveLogSnapshot` struct exactly (snake_case JSON, ISO8601 dates).
public struct SharedDiveLogSnapshot: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public let appleUserId: String              // = ASAuthorizationAppleIDCredential.user
    public let displayName: String
    public let avatarFileName: String?           // relative to App Group container
    public let diveLogHandle: String?            // for divelog://<handle> deep-link; nil in v1
    public let loggedDivesCount: Int
    public let lastDiveDate: Date?
    public let certifications: [Certification]
    public let specialties: [String]
    public let languagesSpoken: [String]
    public let homeBase: String?
    public let conservationProjects: [Project]
    public let snapshotUpdatedAt: Date

    public init(
        schemaVersion: Int = 1,
        appleUserId: String,
        displayName: String,
        avatarFileName: String? = nil,
        diveLogHandle: String? = nil,
        loggedDivesCount: Int,
        lastDiveDate: Date? = nil,
        certifications: [Certification] = [],
        specialties: [String] = [],
        languagesSpoken: [String] = [],
        homeBase: String? = nil,
        conservationProjects: [Project] = [],
        snapshotUpdatedAt: Date
    ) {
        self.schemaVersion = schemaVersion
        self.appleUserId = appleUserId
        self.displayName = displayName
        self.avatarFileName = avatarFileName
        self.diveLogHandle = diveLogHandle
        self.loggedDivesCount = loggedDivesCount
        self.lastDiveDate = lastDiveDate
        self.certifications = certifications
        self.specialties = specialties
        self.languagesSpoken = languagesSpoken
        self.homeBase = homeBase
        self.conservationProjects = conservationProjects
        self.snapshotUpdatedAt = snapshotUpdatedAt
    }

    public struct Certification: Codable, Sendable, Equatable {
        public let agency: String      // PADI/SSI/SDI/TDI/CMAS/RAID/NAUI/BSAC/Other
        public let level: String       // free text — "OWD", "Course Director", …
        public let issuedAt: Date?
        public init(agency: String, level: String, issuedAt: Date?) {
            self.agency = agency
            self.level = level
            self.issuedAt = issuedAt
        }
    }

    public struct Project: Codable, Sendable, Equatable {
        public let title: String
        public let impactText: String?
        public init(title: String, impactText: String?) {
            self.title = title
            self.impactText = impactText
        }
    }
}
