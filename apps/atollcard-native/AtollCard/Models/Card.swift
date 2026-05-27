import Foundation
import SwiftUI

/// A digital business card / persona.
///
/// One Atoll user can own several Cards (Course Director, SeaExplorers Manager,
/// Privat, …). Each Card has its own slug, theme, dive profile, and field
/// visibility — the underlying Person row is shared.
///
/// Maps to the Supabase table `cards`. See README "Schema" section for the
/// full column contract.
public struct Card: Identifiable, Hashable, Sendable, Codable {
  public let id: UUID
  public let personId: UUID
  public var slug: String                  // public URL segment, e.g. "dominik-cd"
  public var title: String                 // "PADI Course Director"
  public var subtitle: String?             // "#226710" / "Owner · SeaExplorers Dauin"
  public var badge: String?                // "PADI CD" / "MANAGER" / "PRIVAT"
  public var theme: CardTheme
  public var diveProfile: DiveProfile?
  public var fieldVisibility: FieldVisibility
  public var isDefault: Bool
  public var isActive: Bool
  public var createdAt: Date
  public var updatedAt: Date

  public init(
    id: UUID,
    personId: UUID,
    slug: String,
    title: String,
    subtitle: String? = nil,
    badge: String? = nil,
    theme: CardTheme,
    diveProfile: DiveProfile? = nil,
    fieldVisibility: FieldVisibility = .standard,
    isDefault: Bool = false,
    isActive: Bool = true,
    createdAt: Date = .now,
    updatedAt: Date = .now
  ) {
    self.id = id
    self.personId = personId
    self.slug = slug
    self.title = title
    self.subtitle = subtitle
    self.badge = badge
    self.theme = theme
    self.diveProfile = diveProfile
    self.fieldVisibility = fieldVisibility
    self.isDefault = isDefault
    self.isActive = isActive
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  /// Full public URL — what the QR code encodes and what AirDrop/iMessage shares.
  public var publicURL: URL {
    Config.publicCardBaseURL.appendingPathComponent(slug)
  }

  enum CodingKeys: String, CodingKey {
    case id
    case personId = "person_id"
    case slug, title, subtitle, badge, theme
    case diveProfile = "dive_profile"
    case fieldVisibility = "field_visibility"
    case isDefault = "is_default"
    case isActive  = "is_active"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }
}

/// Card visual identity — gradient + accent. Stored as jsonb on the DB.
public struct CardTheme: Hashable, Sendable, Codable {
  public var preset: ThemePreset
  /// Optional override of the preset's gradient start/end (hex strings).
  public var gradientStartHex: String?
  public var gradientEndHex: String?
  public var accentHex: String?

  public init(
    preset: ThemePreset,
    gradientStartHex: String? = nil,
    gradientEndHex: String? = nil,
    accentHex: String? = nil
  ) {
    self.preset = preset
    self.gradientStartHex = gradientStartHex
    self.gradientEndHex = gradientEndHex
    self.accentHex = accentHex
  }

  enum CodingKeys: String, CodingKey {
    case preset
    case gradientStartHex = "gradient_start"
    case gradientEndHex   = "gradient_end"
    case accentHex        = "accent"
  }
}

public enum ThemePreset: String, Codable, Sendable, CaseIterable, Identifiable {
  case courseDirector  // blue gradient
  case seaExplorers    // teal gradient
  case privat          // purple gradient
  case custom          // user-defined

  public var id: String { rawValue }

  public var defaultLabel: String {
    switch self {
    case .courseDirector: return "Course Director"
    case .seaExplorers:   return "SeaExplorers"
    case .privat:         return "Privat"
    case .custom:         return "Custom"
    }
  }
}

/// Which Person fields are exposed on the public card page.
public struct FieldVisibility: Hashable, Sendable, Codable {
  public var email: Bool
  public var phone: Bool
  public var whatsapp: Bool
  public var instagram: Bool
  public var linkedin: Bool
  public var website: Bool
  public var diveStats: Bool

  public init(
    email: Bool = true,
    phone: Bool = true,
    whatsapp: Bool = true,
    instagram: Bool = false,
    linkedin: Bool = false,
    website: Bool = true,
    diveStats: Bool = true
  ) {
    self.email = email
    self.phone = phone
    self.whatsapp = whatsapp
    self.instagram = instagram
    self.linkedin = linkedin
    self.website = website
    self.diveStats = diveStats
  }

  public static let standard = FieldVisibility()
}

/// Diving credentials surfaced on the card. Maps to `card_dive_profiles`.
public struct DiveProfile: Hashable, Sendable, Codable {
  public var padiMemberNumber: String?
  public var instructorLevel: InstructorLevel?
  public var specialties: [String]
  public var totalDives: Int?
  public var sinceYear: Int?
  public var teachingLanguages: [String]

  public init(
    padiMemberNumber: String? = nil,
    instructorLevel: InstructorLevel? = nil,
    specialties: [String] = [],
    totalDives: Int? = nil,
    sinceYear: Int? = nil,
    teachingLanguages: [String] = []
  ) {
    self.padiMemberNumber = padiMemberNumber
    self.instructorLevel = instructorLevel
    self.specialties = specialties
    self.totalDives = totalDives
    self.sinceYear = sinceYear
    self.teachingLanguages = teachingLanguages
  }

  enum CodingKeys: String, CodingKey {
    case padiMemberNumber = "padi_member_number"
    case instructorLevel  = "instructor_level"
    case specialties
    case totalDives = "total_dives"
    case sinceYear  = "since_year"
    case teachingLanguages = "teaching_languages"
  }
}

public enum InstructorLevel: String, Codable, Sendable, CaseIterable, Identifiable {
  case openWater = "OWSI"
  case msdt      = "MSDT"
  case idcStaff  = "IDC Staff"
  case masterInstructor = "MI"
  case courseDirector   = "CD"

  public var id: String { rawValue }
}
