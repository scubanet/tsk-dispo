import Foundation

struct SkillDefinition: Codable, Identifiable, Hashable {
  let id: UUID
  let courseTypeCode: String
  let skillCode: String
  let section: String
  let labelDe: String
  let labelEn: String
  let displayOrder: Int

  enum CodingKeys: String, CodingKey {
    case id, section
    case courseTypeCode = "course_type_code"
    case skillCode      = "skill_code"
    case labelDe        = "label_de"
    case labelEn        = "label_en"
    case displayOrder   = "display_order"
  }

  var label: String { labelDe }   // Default fuer alte Call-Sites — wird nach Refactor entfernt

  /// Locale-aware label. Schaut auf den primary language code des aktuellen Locales
  /// und gibt labelEn zurueck wenn "en", sonst labelDe als Default.
  func label(for locale: Locale) -> String {
    locale.language.languageCode?.identifier == "en" ? labelEn : labelDe
  }
}

enum SkillSection {
  static let labelsDe: [String: String] = [
    "cw_dive":    "Confined Water Tauchgänge",
    "assessment": "Beurteilung der Wasserfertigkeiten",
    "cw_flex":    "Tauchgangsflexible Fertigkeiten (CW)",
    "kd":         "Entwicklung der Kenntnisse",
    "ow_dive":    "Freiwasser-Tauchgänge",
    "ow_flex":    "Tauchgangsflexible Fertigkeiten (OW)",
  ]
  static let labelsEn: [String: String] = [
    "cw_dive":    "Confined Water Dives",
    "assessment": "Water Skills Assessment",
    "cw_flex":    "Flexible Skills (CW)",
    "kd":         "Knowledge Development",
    "ow_dive":    "Open Water Dives",
    "ow_flex":    "Flexible Skills (OW)",
  ]
  static let order: [String] = ["cw_dive", "assessment", "cw_flex", "kd", "ow_dive", "ow_flex"]

  /// Locale-aware Section-Label.
  static func label(for code: String, locale: Locale) -> String {
    let isEn = locale.language.languageCode?.identifier == "en"
    let dict = isEn ? labelsEn : labelsDe
    return dict[code] ?? code.uppercased()
  }
}
