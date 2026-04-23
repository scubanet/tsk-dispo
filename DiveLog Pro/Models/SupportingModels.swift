import Foundation
import SwiftData

// ═══════════════════════════════════════
// MARK: - Diver Profile
// ═══════════════════════════════════════

@Model
final class DiverProfile {
    // NOTE: CloudKit requires inline defaults for every non-optional property.
    var name: String = ""
    var padiNumber: String = ""
    var certLevel: String = "OWD"  // OWD, AOWD, Rescue, DM, OWSI, MSDT, IDC Staff, CD
    var isInstructor: Bool = false
    var profileImageData: Data?
    var stampImageData: Data?       // Digitaler Stempel als PNG
    var email: String = ""
    var phone: String = ""

    // Sign in with Apple — stable user identifier linked to this profile.
    // Optional because profiles created before SIWA was introduced won't
    // have one. SwiftData/CloudKit requires optional-default for migration.
    var appleUserID: String?

    // Defaults for new dives (Smart Defaults)
    var defaultSuit: String = "shorty"
    var defaultWeight: Double = 2
    var defaultCylinder: String = "aluminum_12"   // e.g. "aluminum_12"
    var defaultGas: String = "air"
    var defaultDiveCenter: String = ""

    // Preferences
    var useMetric: Bool = true
    var language: String = "en"    // "de" or "en"

    init(
        name: String = "", padiNumber: String = "", certLevel: String = "OWD",
        isInstructor: Bool = false, email: String = "", phone: String = "",
        defaultSuit: String = "shorty", defaultWeight: Double = 2,
        defaultCylinder: String = "aluminum_12", defaultGas: String = "air",
        defaultDiveCenter: String = "",
        useMetric: Bool = true, language: String = "en",
        appleUserID: String? = nil
    ) {
        self.name = name; self.padiNumber = padiNumber; self.certLevel = certLevel
        self.isInstructor = isInstructor; self.email = email; self.phone = phone
        self.profileImageData = nil; self.stampImageData = nil
        self.defaultSuit = defaultSuit; self.defaultWeight = defaultWeight
        self.defaultCylinder = defaultCylinder; self.defaultGas = defaultGas
        self.defaultDiveCenter = defaultDiveCenter
        self.useMetric = useMetric; self.language = language
        self.appleUserID = appleUserID
    }
}

// ═══════════════════════════════════════
// MARK: - Dive Site
// ═══════════════════════════════════════

@Model
final class DiveSite {
    var name: String = ""
    var region: String = ""         // Stadt/Region
    var country: String = ""
    var latitude: Double = 0
    var longitude: Double = 0
    var siteDescription: String = ""
    var maxDepthTypical: Double = 0
    var typicalCurrent: String = "none"
    var typicalVisibility: Int = 15
    var entryType: String = "boat"  // boat, shore
    var difficulty: String = "easy" // easy, moderate, advanced, expert
    var isFavorite: Bool = false

    // CloudKit requires to-many relationships to be optional.
    @Relationship(inverse: \Dive.diveSite) var dives: [Dive]? = []
    
    init(
        name: String = "", region: String = "", country: String = "",
        latitude: Double = 0, longitude: Double = 0, siteDescription: String = "",
        maxDepthTypical: Double = 0, typicalCurrent: String = "none",
        typicalVisibility: Int = 15, entryType: String = "boat",
        difficulty: String = "easy", isFavorite: Bool = false
    ) {
        self.name = name; self.region = region; self.country = country
        self.latitude = latitude; self.longitude = longitude
        self.siteDescription = siteDescription
        self.maxDepthTypical = maxDepthTypical; self.typicalCurrent = typicalCurrent
        self.typicalVisibility = typicalVisibility; self.entryType = entryType
        self.difficulty = difficulty; self.isFavorite = isFavorite
        self.dives = []
    }
}

// ═══════════════════════════════════════
// MARK: - Buddy
// ═══════════════════════════════════════

@Model
final class Buddy {
    var name: String = ""
    var padiNumber: String = ""
    var certLevel: String = ""
    var email: String = ""
    var phone: String = ""
    var stampImageData: Data?
    var diveCount: Int = 0          // Anzahl gemeinsamer TGs

    // CloudKit requires to-many relationships to be optional.
    @Relationship(inverse: \Dive.buddies) var dives: [Dive]? = []
    
    init(
        name: String = "", padiNumber: String = "", certLevel: String = "",
        email: String = "", phone: String = "", diveCount: Int = 0
    ) {
        self.name = name; self.padiNumber = padiNumber; self.certLevel = certLevel
        self.email = email; self.phone = phone
        self.stampImageData = nil; self.diveCount = diveCount
        self.dives = []
    }
}

// ═══════════════════════════════════════
// MARK: - Dive Signature
// ═══════════════════════════════════════

@Model
final class DiveSignature {
    var buddyName: String = ""
    var buddyPadiNumber: String = ""
    var method: String = "finger"   // qr, finger, link
    var signedAt: Date = Date.now
    var signatureImageData: Data?   // Finger-Signatur als PNG
    var qrHash: String = ""         // QR-Verifizierung
    var linkToken: String = ""      // Link-Token
    var isVerified: Bool = false
    var stampImageData: Data?       // Buddy's Stempel

    @Relationship(inverse: \Dive.signatures) var dive: Dive?
    
    init(
        buddyName: String = "", buddyPadiNumber: String = "",
        method: String = "finger", signedAt: Date = .now,
        isVerified: Bool = false
    ) {
        self.buddyName = buddyName; self.buddyPadiNumber = buddyPadiNumber
        self.method = method; self.signedAt = signedAt
        self.signatureImageData = nil; self.qrHash = ""; self.linkToken = ""
        self.isVerified = isVerified; self.stampImageData = nil
        self.dive = nil
    }
}
