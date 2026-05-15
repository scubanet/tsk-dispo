import Foundation

public struct SkillDefinition: Codable, Identifiable, Hashable {
  public let id: UUID
  public let courseTypeCode: String
  public let skillCode: String
  public let section: String
  public let labelDe: String
  public let labelEn: String
  public let displayOrder: Int

  enum CodingKeys: String, CodingKey {
    case id, section
    case courseTypeCode = "course_type_code"
    case skillCode      = "skill_code"
    case labelDe        = "label_de"
    case labelEn        = "label_en"
    case displayOrder   = "display_order"
  }

  public var label: String { labelDe }   // Default fuer alte Call-Sites — wird nach Refactor entfernt

  /// Locale-aware label. Schaut auf den primary language code des aktuellen Locales
  /// und gibt labelEn zurueck wenn "en", sonst labelDe als Default.
  public func label(for locale: Locale) -> String {
    locale.language.languageCode?.identifier == "en" ? labelEn : labelDe
  }
}

public enum SkillSection {
  public static let labelsDe: [String: String] = [
    "cw_dive":    "Confined Water Tauchgänge",
    "assessment": "Beurteilung der Wasserfertigkeiten",
    "cw_flex":    "Tauchgangsflexible Fertigkeiten (CW)",
    "kd":         "Entwicklung der Kenntnisse",
    "ow_dive":    "Freiwasser-Tauchgänge",
    "ow_flex":    "Tauchgangsflexible Fertigkeiten (OW)",
  ]
  public static let labelsEn: [String: String] = [
    "cw_dive":    "Confined Water Dives",
    "assessment": "Water Skills Assessment",
    "cw_flex":    "Flexible Skills (CW)",
    "kd":         "Knowledge Development",
    "ow_dive":    "Open Water Dives",
    "ow_flex":    "Flexible Skills (OW)",
  ]
  public static let order: [String] = ["cw_dive", "assessment", "cw_flex", "kd", "ow_dive", "ow_flex"]

  /// Locale-aware Section-Label.
  public static func label(for code: String, locale: Locale) -> String {
    let isEn = locale.language.languageCode?.identifier == "en"
    let dict = isEn ? labelsEn : labelsDe
    return dict[code] ?? code.uppercased()
  }
}
