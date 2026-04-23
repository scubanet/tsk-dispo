import SwiftUI

// ═══════════════════════════════════════
// MARK: - Brand Colors
// ═══════════════════════════════════════

extension Color {
    static let deepOcean = Color(red: 11/255, green: 29/255, blue: 46/255)
    static let oceanBlue = Color(red: 0/255, green: 119/255, blue: 182/255)
    static let coral = Color(red: 232/255, green: 114/255, blue: 90/255)
    static let seafoam = Color(red: 144/255, green: 224/255, blue: 200/255)
    static let sandLight = Color(red: 245/255, green: 240/255, blue: 232/255)
    
    static let cardBg = Color.white.opacity(0.03)
    static let cardBorder = Color.white.opacity(0.05)
    static let labelDim = Color.white.opacity(0.4)
    static let textDim = Color.white.opacity(0.5)

    // Semantic aliases used by the new design system
    static let appAccent = Color.oceanBlue
    static let appSuccess = Color.seafoam
    static let appEmphasis = Color.coral
    static let surfaceElevated = Color.deepOcean
    static let surfaceCard = Color.white.opacity(0.04)
    static let hairline = Color.white.opacity(0.12)
}

// ═══════════════════════════════════════
// MARK: - Design System Tokens
// ═══════════════════════════════════════

enum DSSpacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48
}

enum DSRadius {
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 28
}

// ═══════════════════════════════════════
// MARK: - Localization
// ═══════════════════════════════════════

enum L10n {
    // Tabs
    static var tabLogbook: String { loc("Logbook", de: "Logbuch") }
    static var tabJournal: String { loc("Journal", de: "Journal") }
    static var tabSign: String { loc("Sign", de: "Signieren") }
    static var tabStats: String { loc("Statistics", de: "Statistiken") }
    static var tabProfile: String { loc("Profile", de: "Profil") }
    
    // Logbook
    static var totalDives: String { loc("total dives", de: "Tauchgänge") }
    static var searchPlaceholder: String { loc("Search dives, sites, buddies...", de: "Suche TGs, Plätze, Buddies...") }
    
    // Dive Form
    static var quickLog: String { loc("Quick Log", de: "Schnelleingabe") }
    static var editDive: String { loc("Edit Dive", de: "TG bearbeiten") }
    static var saveDive: String { loc("Save Dive", de: "TG speichern") }
    static var updateDive: String { loc("Update Dive", de: "TG aktualisieren") }
    static var next: String { loc("Next", de: "Weiter") }
    static var back: String { loc("Back", de: "Zurück") }
    
    // Steps
    static var stepBasics: String { loc("Dive Basics", de: "TG Basics") }
    static var stepEquipment: String { loc("Equipment & Gas", de: "Ausrüstung & Gas") }
    static var stepJournal: String { loc("Journal & Experience", de: "Journal & Erlebnis") }
    
    // Fields
    static var diveSite: String { loc("Dive Site", de: "Tauchplatz") }
    static var location: String { loc("Location", de: "Ort") }
    static var diveType: String { loc("Dive Type", de: "Tauchgangstyp") }
    static var maxDepth: String { loc("Max Depth", de: "Max. Tiefe") }
    static var avgDepth: String { loc("Avg Depth", de: "Ø Tiefe") }
    static var bottomTime: String { loc("Bottom Time", de: "Grundzeit") }
    static var totalTime: String { loc("Total Time", de: "Tauchzeit") }
    static var entry: String { loc("Entry", de: "Einstieg") }
    static var weatherLabel: String { loc("Weather", de: "Wetter") }
    static var airTempLabel: String { loc("Air Temp", de: "Luft-Temp") }
    static var waterTempSurface: String { loc("Surface Temp", de: "Wasser Oberfläche") }
    static var waterTempBottom: String { loc("Bottom Temp", de: "Wasser Tiefe") }
    static var visibilityLabel: String { loc("Visibility", de: "Sicht") }
    static var currentLabel: String { loc("Current", de: "Strömung") }
    static var wavesLabel: String { loc("Waves", de: "Wellengang") }
    static var suitLabel: String { loc("Suit", de: "Anzug") }
    static var weightLabel: String { loc("Weight", de: "Blei") }
    static var cylinderLabel: String { loc("Cylinder", de: "Flasche") }
    static var gasLabel: String { loc("Gas", de: "Gas") }
    static var tankStart: String { loc("Tank Start", de: "Flaschendruck Start") }
    static var tankEnd: String { loc("Tank End", de: "Flaschendruck Ende") }
    static var feeling: String { loc("Feeling", de: "Gefühl") }
    static var buddyLabel: String { loc("Buddy", de: "Tauchpartner") }
    static var marineLifeLabel: String { loc("Marine Life", de: "Unterwasserwelt") }
    static var notesLabel: String { loc("Notes", de: "Notizen") }
    static var photosLabel: String { loc("Photos", de: "Fotos") }
    static var diveCenterLabel: String { loc("Dive Center", de: "Tauchbasis") }
    
    // Detail tabs
    static var overview: String { loc("Overview", de: "Übersicht") }
    static var profile: String { loc("Profile", de: "Profil") }
    static var stats: String { loc("Stats", de: "Daten") }
    static var gear: String { loc("Gear", de: "Ausrüstung") }
    static var journal: String { loc("Journal", de: "Journal") }
    
    // Conditions
    static var conditions: String { loc("Conditions", de: "Bedingungen") }
    static var buddies: String { loc("Dive Buddies", de: "Tauchpartner") }
    static var signatures: String { loc("Signatures", de: "Unterschriften") }
    
    // Stats
    static var totalDivesCount: String { loc("Total Dives", de: "Tauchgänge gesamt") }
    static var hoursUnderwater: String { loc("hours underwater", de: "Stunden unter Wasser") }
    static var deepestDive: String { loc("Deepest", de: "Tiefster") }
    static var longestDive: String { loc("Longest", de: "Längster") }
    static var avgSac: String { loc("Avg SAC", de: "Ø SAC") }
    
    // Values
    static var none: String { loc("None", de: "Keine") }
    static var light: String { loc("Light", de: "Leicht") }
    static var moderate: String { loc("Moderate", de: "Mittel") }
    static var strong: String { loc("Strong", de: "Stark") }
    static var calm: String { loc("Calm", de: "Ruhig") }
    static var slight: String { loc("Slight", de: "Leicht") }
    static var rough: String { loc("Rough", de: "Rau") }

    // Location & Weather
    static var gpsLabel: String { loc("Location (GPS)", de: "Standort (GPS)") }
    static var currentLocation: String { loc("Use Current Location", de: "Aktuellen Standort nutzen") }
    static var loadingWeather: String { loc("Loading weather…", de: "Wetter wird geladen…") }
    static var weatherUnavailable: String { loc("Weather unavailable", de: "Wetter nicht verfügbar") }

    // QR Code
    static var scanHint: String { loc("Point at a buddy's QR code", de: "Auf den QR-Code des Buddys richten") }
    static var invalidQR: String { loc("Invalid QR code", de: "Ungültiger QR-Code") }
    static var myQRTitle: String { loc("My QR Code", de: "Mein QR-Code") }
    static var qrShareHint: String {
        loc("Show this code to your buddy. They scan it on their device to pre-fill your details.",
            de: "Zeig diesen Code deinem Buddy. Beim Scan auf dessen Gerät werden deine Daten übernommen.")
    }

    // Remote Link Signature
    static var sendLinkTitle: String { loc("Send Signature Link", de: "Signatur-Link senden") }
    static var generatingLink: String { loc("Creating secure link…", de: "Link wird erstellt…") }
    static var linkReady: String { loc("Link ready", de: "Link bereit") }
    static var linkShareHint: String {
        loc("Share this link with your buddy. Tapping it opens DiveLog Pro so they can sign remotely.",
            de: "Teile den Link mit deinem Buddy. Beim Öffnen startet DiveLog Pro, damit er aus der Ferne unterschreiben kann.")
    }
    static var shareLink: String { loc("Share Link", de: "Link teilen") }
    static var copyLink: String { loc("Copy Link", de: "Link kopieren") }
    static var waitingForSignature: String {
        loc("Waiting for your buddy to sign…", de: "Warte auf die Unterschrift deines Buddys…")
    }
    static var remoteSignTitle: String { loc("Sign a Dive", de: "TG signieren") }
    static var remoteSignLoading: String { loc("Loading dive details…", de: "Lade TG-Daten…") }
    static var remoteSignExpired: String { loc("This signature link has expired.", de: "Dieser Link ist abgelaufen.") }
    static var remoteSignNotFound: String { loc("Signature link not found.", de: "Signatur-Link nicht gefunden.") }
    static var remoteSignThanks: String { loc("Signature sent!", de: "Unterschrift gesendet!") }

    // Sign in with Apple
    static var signInWithApple: String { loc("Sign in with Apple", de: "Mit Apple anmelden") }
    static var signInSubtitle: String {
        loc("Your digital dive log.", de: "Dein digitales Tauchlogbuch.")
    }
    static var signInPrivacyHint: String {
        loc("Apple only shares your name and (optionally) email. No passwords, no tracking.",
            de: "Apple gibt uns nur deinen Namen und (optional) deine E-Mail. Keine Passwörter, keine Werbung.")
    }
    static var signOut: String { loc("Sign Out", de: "Abmelden") }
    static var signOutConfirmTitle: String { loc("Sign out?", de: "Wirklich abmelden?") }
    static var signOutConfirmBody: String {
        loc("Your dives stay in iCloud. You just have to sign in with Apple again.",
            de: "Deine Tauchgänge bleiben in iCloud. Du musst dich nur wieder mit Apple anmelden.")
    }
    static var deleteAccount: String { loc("Delete Account", de: "Account löschen") }
    static var deleteAccountConfirmTitle: String {
        loc("Really delete account?", de: "Account wirklich löschen?")
    }
    static var deleteAccountConfirmBody: String {
        loc("All dives, buddies, sites and your profile will be removed from this device and your iCloud. This cannot be undone.",
            de: "Alle Tauchgänge, Buddies, Tauchplätze und dein Profil werden von diesem Gerät und aus deinem iCloud entfernt. Das lässt sich nicht rückgängig machen.")
    }

    // ─── Language Engine ─────────────────
    
    @AppStorage("appLanguage") static var currentLanguage: String = "en"
    
    static func loc(_ en: String, de: String) -> String {
        currentLanguage == "de" ? de : en
    }
}

// ═══════════════════════════════════════
// MARK: - Dive Type Options
// ═══════════════════════════════════════

struct DiveTypeOption: Identifiable {
    let id: String
    let en: String
    let de: String
    let icon: String
    
    var label: String { L10n.currentLanguage == "de" ? de : en }
    
    static let all: [DiveTypeOption] = [
        .init(id: "fun",      en: "Fun Dive",  de: "Fun Dive",     icon: "water.waves"),
        .init(id: "training", en: "Training",   de: "Training",     icon: "graduationcap.fill"),
        .init(id: "night",    en: "Night Dive", de: "Nachttauchgang", icon: "moon.stars.fill"),
        .init(id: "drift",    en: "Drift Dive", de: "Strömungstauchen", icon: "wind"),
        .init(id: "deep",     en: "Deep Dive",  de: "Tieftauchgang", icon: "arrow.down.to.line"),
        .init(id: "wreck",    en: "Wreck Dive", de: "Wracktauchen", icon: "ferry.fill"),
        .init(id: "cave",     en: "Cave Dive",  de: "Höhlentauchen", icon: "mountain.2.fill"),
        .init(id: "photo",    en: "Photo Dive", de: "Fototauchen",  icon: "camera.fill"),
    ]
}
