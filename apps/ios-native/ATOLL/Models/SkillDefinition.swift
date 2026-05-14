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

  var label: String { labelDe }
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
  static let order: [String] = ["cw_dive", "assessment", "cw_flex", "kd", "ow_dive", "ow_flex"]
}
