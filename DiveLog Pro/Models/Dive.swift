import Foundation
import SwiftData

@Model
final class Dive {
    // ─── Basis ───────────────────────────
    // NOTE: Every stored property MUST have an inline default (or be optional).
    // CloudKit integration refuses to load the store otherwise. The `init`
    // parameters still override these defaults.
    var number: Int = 0
    var date: Date = Date.now
    var diveType: String = "fun"       // fun, training, night, drift, deep, wreck, cave, photo

    // ─── Ort ─────────────────────────────
    var siteName: String = ""
    var siteLocation: String = ""      // Stadt/Land
    var latitude: Double = 0
    var longitude: Double = 0
    var diveCenterName: String = ""

    // ─── Tiefe & Zeit ────────────────────
    var maxDepth: Double = 0           // meters
    var avgDepth: Double = 0
    var bottomTime: Int = 0            // minutes
    var totalTime: Int = 0             // minutes (inkl. Safety Stop)
    var safetyStopMin: Int = 3
    var entryType: String = "boat"     // boat, shore

    // ─── Bedingungen ─────────────────────
    var weather: String = "sunny"      // sunny, partly_cloudy, cloudy, rainy, windy, foggy
    var airTemp: Double = 30           // °C
    var waterTempSurface: Double = 28
    var waterTempBottom: Double = 27
    var visibility: Int = 15           // meters
    var current: String = "none"       // none, light, moderate, strong
    var waves: String = "calm"         // calm, slight, moderate, rough
    var waterType: String = "salt"     // salt, fresh, brackish

    // ─── Ausrüstung ─────────────────────
    var suit: String = "shorty"        // none, shorty, 3mm, 5mm, 7mm, semi_dry, drysuit
    var weightKg: Double = 2
    var weightFeel: String = "good"    // light, good, heavy
    var cylinderType: String = "aluminum" // aluminum, steel
    var cylinderSizeLiters: Double = 12
    var gas: String = "air"            // air, eanx32, eanx36, eanx40, trimix, rebreather
    var tankStartBar: Int = 200
    var tankEndBar: Int = 50
    var sacRate: Double = 12           // l/min

    // ─── Computer ────────────────────────
    var computerModel: String = ""
    var algorithm: String = ""
    var gradientFactors: String = ""
    var n2LoadStart: Int = 0           // %
    var n2LoadEnd: Int = 0
    var cnsStart: Int = 0              // %
    var cnsEnd: Int = 0

    // ─── Physiologie ─────────────────────
    var hrAvg: Int = 0                 // bpm
    var hrMax: Int = 0
    var calories: Int = 0

    // ─── Journal ─────────────────────────
    var notes: String = ""
    var feeling: String = "good"       // amazing, good, average, poor
    var rating: Int = 0                // 1-5 stars
    var isHighlight: Bool = false

    // ─── Fotos ───────────────────────────
    // Stored as filenames, actual files in app documents directory
    var photoFilenamesRaw: String = ""

    // CloudKit-mirrored binary copies (per filename) — used by PhotoStore
    // to back up photos to iCloud without inflating the dive document.
    @Relationship(deleteRule: .cascade, inverse: \DivePhoto.dive)
    var photos: [DivePhoto]? = []

    // ─── Marine Life ─────────────────────
    var marineLifeRaw: String = ""

    // ─── Depth Profile ───────────────────
    var depthProfileRaw: String = ""

    // ─── Signaturen ──────────────────────
    @Relationship(deleteRule: .cascade) var signatures: [DiveSignature]? = []

    // ─── Buddy ───────────────────────────
    var buddyNames: String = ""        // comma-separated for quick display
    @Relationship var buddies: [Buddy]? = []

    // ─── Instructor / Course ─────────────
    // Optional — nil = recreational fun dive, not course-related.
    var courseType: String?        // "OWD", "AOWD"
    var courseSlot: String?        // "OW1", "OW2", "AOWD-Deep"
    var extraSkillCodesRaw: String = ""  // pipe-separated extra skill codes from other slots/courses

    @Relationship(deleteRule: .nullify, inverse: \Student.dives)
    var students: [Student]? = []

    @Relationship(deleteRule: .cascade, inverse: \SkillCompletion.dive)
    var skillCompletions: [SkillCompletion]? = []

    // ─── Tauchplatz Referenz ─────────────
    @Relationship var diveSite: DiveSite?
    
    // ═══════════════════════════════════════
    // MARK: - Computed Properties
    // ═══════════════════════════════════════
    
    var tankUsed: Int { max(0, tankStartBar - tankEndBar) }
    var barPerMinute: Double { totalTime > 0 ? Double(tankUsed) / Double(totalTime) : 0 }
    
    var marineLife: [String] {
        get { marineLifeRaw.isEmpty ? [] : marineLifeRaw.components(separatedBy: "||") }
        set { marineLifeRaw = newValue.joined(separator: "||") }
    }
    
    var photoFilenames: [String] {
        get { photoFilenamesRaw.isEmpty ? [] : photoFilenamesRaw.components(separatedBy: "||") }
        set { photoFilenamesRaw = newValue.joined(separator: "||") }
    }

    var extraSkillCodes: [String] {
        get { extraSkillCodesRaw.isEmpty ? [] : extraSkillCodesRaw.components(separatedBy: "||") }
        set { extraSkillCodesRaw = newValue.joined(separator: "||") }
    }
    
    var depthProfile: [Double] {
        get { depthProfileRaw.isEmpty ? [] : depthProfileRaw.components(separatedBy: ",").compactMap { Double($0) } }
        set { depthProfileRaw = newValue.map { String(format: "%.1f", $0) }.joined(separator: ",") }
    }
    
    var buddyList: [String] {
        buddyNames.isEmpty ? [] : buddyNames.components(separatedBy: ", ")
    }
    
    var feelingEmoji: String {
        switch feeling {
        case "amazing": return "🤩"
        case "good":    return "😊"
        case "average": return "😐"
        case "poor":    return "😕"
        default:        return "😊"
        }
    }
    
    var weatherSFSymbol: String {
        switch weather {
        case "sunny":         return "sun.max.fill"
        case "partly_cloudy": return "cloud.sun.fill"
        case "cloudy":        return "cloud.fill"
        case "rainy":         return "cloud.rain.fill"
        case "windy":         return "wind"
        case "foggy":         return "cloud.fog.fill"
        default:              return "sun.max.fill"
        }
    }
    
    var diveTypeIcon: String {
        switch diveType {
        case "night":    return "moon.stars.fill"
        case "drift":    return "water.waves"
        case "deep":     return "arrow.down.to.line"
        case "wreck":    return "ferry.fill"
        case "cave":     return "mountain.2.fill"
        case "photo":    return "camera.fill"
        case "training": return "graduationcap.fill"
        default:         return "water.waves"
        }
    }
    
    var formattedDate: String {
        date.formatted(.dateTime.day().month(.abbreviated).year())
    }
    
    var formattedTime: String {
        date.formatted(.dateTime.hour().minute())
    }
    
    // ═══════════════════════════════════════
    // MARK: - Init
    // ═══════════════════════════════════════
    
    init(
        number: Int = 0, date: Date = .now, diveType: String = "fun",
        siteName: String = "", siteLocation: String = "",
        latitude: Double = 0, longitude: Double = 0, diveCenterName: String = "",
        maxDepth: Double = 0, avgDepth: Double = 0, bottomTime: Int = 0, totalTime: Int = 0,
        safetyStopMin: Int = 3, entryType: String = "boat",
        weather: String = "sunny", airTemp: Double = 30,
        waterTempSurface: Double = 28, waterTempBottom: Double = 27,
        visibility: Int = 15, current: String = "none", waves: String = "calm", waterType: String = "salt",
        suit: String = "shorty", weightKg: Double = 2, weightFeel: String = "good",
        cylinderType: String = "aluminum", cylinderSizeLiters: Double = 12, gas: String = "air",
        tankStartBar: Int = 200, tankEndBar: Int = 50, sacRate: Double = 12,
        computerModel: String = "", algorithm: String = "", gradientFactors: String = "",
        n2LoadStart: Int = 0, n2LoadEnd: Int = 0, cnsStart: Int = 0, cnsEnd: Int = 0,
        hrAvg: Int = 0, hrMax: Int = 0, calories: Int = 0,
        notes: String = "", feeling: String = "good", rating: Int = 0, isHighlight: Bool = false,
        buddyNames: String = "", marineLife: [String] = [], depthProfile: [Double] = []
    ) {
        self.number = number; self.date = date; self.diveType = diveType
        self.siteName = siteName; self.siteLocation = siteLocation
        self.latitude = latitude; self.longitude = longitude; self.diveCenterName = diveCenterName
        self.maxDepth = maxDepth; self.avgDepth = avgDepth
        self.bottomTime = bottomTime; self.totalTime = totalTime
        self.safetyStopMin = safetyStopMin; self.entryType = entryType
        self.weather = weather; self.airTemp = airTemp
        self.waterTempSurface = waterTempSurface; self.waterTempBottom = waterTempBottom
        self.visibility = visibility; self.current = current; self.waves = waves; self.waterType = waterType
        self.suit = suit; self.weightKg = weightKg; self.weightFeel = weightFeel
        self.cylinderType = cylinderType; self.cylinderSizeLiters = cylinderSizeLiters; self.gas = gas
        self.tankStartBar = tankStartBar; self.tankEndBar = tankEndBar; self.sacRate = sacRate
        self.computerModel = computerModel; self.algorithm = algorithm; self.gradientFactors = gradientFactors
        self.n2LoadStart = n2LoadStart; self.n2LoadEnd = n2LoadEnd
        self.cnsStart = cnsStart; self.cnsEnd = cnsEnd
        self.hrAvg = hrAvg; self.hrMax = hrMax; self.calories = calories
        self.notes = notes; self.feeling = feeling; self.rating = rating; self.isHighlight = isHighlight
        self.buddyNames = buddyNames
        self.marineLifeRaw = marineLife.joined(separator: "||")
        self.photoFilenamesRaw = ""
        self.depthProfileRaw = depthProfile.map { String(format: "%.1f", $0) }.joined(separator: ",")
        self.signatures = []
        self.buddies = []
        self.diveSite = nil
    }
}
