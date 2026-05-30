import Foundation

/// Deterministic mock data so the app boots looking like the Fantastical-
/// style mockup right out of the box. Re-uses the same UUIDs across runs
/// (`uuid(_:)`) so SwiftUI list animations don't shuffle on relaunch.
enum MockSeed {
  // Stable UUIDs ---------------------------------------------------------

  /// Build a deterministic UUID from a tag string. Lets us reference the
  /// same card / lead from multiple seeds without juggling random IDs.
  static func uuid(_ tag: String) -> UUID {
    var bytes = Array(tag.utf8)
    while bytes.count < 16 { bytes.append(0) }
    let truncated = Array(bytes.prefix(16))
    let uuidBytes = (
      truncated[0], truncated[1], truncated[2],  truncated[3],
      truncated[4], truncated[5], truncated[6],  truncated[7],
      truncated[8], truncated[9], truncated[10], truncated[11],
      truncated[12], truncated[13], truncated[14], truncated[15]
    )
    return UUID(uuid: uuidBytes)
  }

  // Person ---------------------------------------------------------------

  static let dominik = Person(
    id: uuid("person-dw"),
    firstName: "Dominik",
    lastName: "Weckherlin",
    emailPrimary: "weckherlin@icloud.com",
    phonePrimary: "+41 79 000 00 00",
    languages: ["DE", "EN", "FR", "IT"],
    padiMemberNumber: "226710",
    avatarColorHex: "#52668A"
  )

  // Cards ----------------------------------------------------------------

  static let cards: [Card] = [
    Card(
      id: uuid("card-cd"),
      personId: dominik.id,
      slug: "dominik-cd",
      title: "PADI Course Director",
      subtitle: "#226710",
      badge: "PADI CD",
      theme: CardTheme(preset: .courseDirector),
      diveProfile: DiveProfile(
        padiMemberNumber: "226710",
        instructorLevel: .courseDirector,
        specialties: ["Deep", "Nitrox", "Wreck", "Drift", "DPV",
                      "Search & Recovery", "Underwater Navigator",
                      "Equipment Specialist", "Boat Diver", "Self-Reliant",
                      "Sidemount", "Emergency O₂"],
        totalDives: 7800,
        sinceYear: 2008,
        teachingLanguages: ["DE", "EN", "FR"]
      ),
      isDefault: true
    ),
    Card(
      id: uuid("card-se"),
      personId: dominik.id,
      slug: "dominik-seaexplorers",
      title: "SeaExplorers Manager",
      subtitle: "Owner · Dauin",
      badge: "MANAGER",
      theme: CardTheme(preset: .seaExplorers),
      diveProfile: DiveProfile(
        instructorLevel: .courseDirector,
        specialties: ["Boat", "Drift"],
        totalDives: 7800,
        teachingLanguages: ["EN"]
      )
    ),
    Card(
      id: uuid("card-priv"),
      personId: dominik.id,
      slug: "dominik",
      title: "Privat",
      subtitle: nil,
      badge: "PRIVAT",
      theme: CardTheme(preset: .privat),
      fieldVisibility: FieldVisibility(email: true, phone: true, whatsapp: true,
                                       instagram: true, linkedin: false,
                                       website: false, diveStats: false)
    ),
  ]

  // Leads ----------------------------------------------------------------

  static let leads: [Lead] = {
    let cdId  = uuid("card-cd")
    let seId  = uuid("card-se")
    let now   = Date()
    let cal   = Calendar.current
    func ago(_ days: Int, _ hours: Int = 0) -> Date {
      cal.date(byAdding: DateComponents(day: -days, hour: -hours), to: now) ?? now
    }
    return [
      Lead(id: uuid("lead-marcus"),  cardId: cdId,
           firstName: "Marcus", lastName: "Kessler",
           email: "marcus@example.com",
           phone: "+49 171 0000000",
           topic: "IDC 2026 Anfrage",
           capturedAt: ago(0, 2),
           ipCountry: "DE",
           status: .new,
           avatarColorHex: "#b8893a"),
      Lead(id: uuid("lead-anna"),    cardId: seId,
           firstName: "Anna", lastName: "Nguyen",
           email: "anna@example.com",
           topic: "Trial Dive Anfrage",
           capturedAt: ago(0, 4),
           ipCountry: "PH",
           status: .new,
           avatarColorHex: "#5fa86a"),
      Lead(id: uuid("lead-lisa"),    cardId: cdId,
           firstName: "Lisa", lastName: "Frey",
           email: "lisa@example.com",
           topic: "Divemaster Q&A",
           capturedAt: ago(1, 0),
           ipCountry: "CH",
           status: .opened,
           avatarColorHex: "#6b5b9e"),
      Lead(id: uuid("lead-ravi"),    cardId: seId,
           firstName: "Ravi", lastName: "Tan",
           email: "ravi@example.com",
           topic: "DM Reise Dauin",
           capturedAt: ago(1, 8),
           ipCountry: "SG",
           status: .opened,
           avatarColorHex: "#b85577"),
      Lead(id: uuid("lead-thomas"),  cardId: cdId,
           firstName: "Thomas", lastName: "Schmid",
           email: "thomas@example.com",
           topic: "OWSI Crossover",
           capturedAt: ago(4, 0),
           ipCountry: "AT",
           status: .contacted,
           avatarColorHex: "#5b8a72"),
      Lead(id: uuid("lead-julia"),   cardId: cdId,
           firstName: "Julia", lastName: "Caine",
           email: "julia@example.com",
           topic: "IDC Schedule",
           capturedAt: ago(4, 4),
           ipCountry: "CH",
           status: .contacted,
           avatarColorHex: "#b03844"),
      Lead(id: uuid("lead-pierre"),  cardId: cdId,
           firstName: "Pierre", lastName: "Dubois",
           email: "pierre@example.com",
           topic: "Specialty Bundle",
           capturedAt: ago(5, 2),
           ipCountry: "FR",
           importedToAddressBook: true,
           status: .imported,
           avatarColorHex: "#4a8de8"),
      Lead(id: uuid("lead-kenji"),   cardId: cdId,
           firstName: "Kenji", lastName: "Sato",
           email: "kenji@example.com",
           topic: "Course Director Wissen",
           capturedAt: ago(6, 0),
           ipCountry: "JP",
           status: .opened,
           avatarColorHex: "#a87547"),
    ]
  }()

  // Analytics ------------------------------------------------------------

  static func analytics(for cardId: UUID, range: DateRangeOption) -> CardAnalytics {
    let days = range.days ?? 90
    let cal = Calendar.current
    let scansByDay: [DailyCount] = (0..<days).reversed().map { offset in
      let date = cal.date(byAdding: .day, value: -offset, to: cal.startOfDay(for: .now)) ?? .now
      // Pseudo-random but deterministic per day-offset/card combo.
      let hash = abs((cardId.uuidString + "\(offset)").hashValue)
      let count = (hash % 7) + (offset < 4 ? 2 : 0)
      return DailyCount(date: date, count: count)
    }
    let leadsByDay = scansByDay.map { DailyCount(date: $0.date, count: max(0, $0.count / 3)) }
    let totalScans = scansByDay.reduce(0) { $0 + $1.count }
    let totalLeads = leadsByDay.reduce(0) { $0 + $1.count }
    return CardAnalytics(
      cardId: cardId,
      range: range,
      totalScans: totalScans,
      totalLeads: totalLeads,
      conversionRate: totalScans == 0 ? 0 : Double(totalLeads) / Double(totalScans),
      scansByDay: scansByDay,
      leadsByDay: leadsByDay,
      scansByCountry: ["CH": 14, "DE": 8, "PH": 5, "AT": 3, "FR": 2, "JP": 2, "SG": 1, "IT": 1],
      scansByField: [.email: 18, .phone: 9, .whatsapp: 7, .website: 5, .leadForm: 11]
    )
  }

  static func aggregateAnalytics(range: DateRangeOption) -> CardAnalytics {
    // Sum across all cards — for the "Aggregate" tab in AnalyticsView.
    let perCard = cards.map { analytics(for: $0.id, range: range) }
    let days = perCard.first?.scansByDay.map(\.date) ?? []
    let scansByDay = days.enumerated().map { idx, date in
      DailyCount(date: date, count: perCard.reduce(0) { $0 + ($1.scansByDay[safe: idx]?.count ?? 0) })
    }
    let leadsByDay = days.enumerated().map { idx, date in
      DailyCount(date: date, count: perCard.reduce(0) { $0 + ($1.leadsByDay[safe: idx]?.count ?? 0) })
    }
    let totalScans = perCard.reduce(0) { $0 + $1.totalScans }
    let totalLeads = perCard.reduce(0) { $0 + $1.totalLeads }
    var country: [String: Int] = [:]
    var field: [Scan.TappedField: Int] = [:]
    for a in perCard {
      a.scansByCountry.forEach { country[$0.key, default: 0] += $0.value }
      a.scansByField.forEach   { field[$0.key,   default: 0] += $0.value }
    }
    return CardAnalytics(
      cardId: uuid("aggregate"),
      range: range,
      totalScans: totalScans,
      totalLeads: totalLeads,
      conversionRate: totalScans == 0 ? 0 : Double(totalLeads) / Double(totalScans),
      scansByDay: scansByDay,
      leadsByDay: leadsByDay,
      scansByCountry: country,
      scansByField: field
    )
  }
}

private extension Array {
  subscript(safe idx: Int) -> Element? {
    indices.contains(idx) ? self[idx] : nil
  }
}
