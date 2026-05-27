import Foundation
import Supabase
import AtollCore
import OSLog

/// Loads the signed-in instructor's *teachable* PADI specialties from the
/// Atoll OS master catalog. Used by `CardEditorSheet` to render the
/// SpecialtyGrid pills — replaces the previously hardcoded 15-entry list.
///
/// **Why pull from the main app?**
///   • Single source of truth — when a new specialty is added (or one is
///     retired) in Atoll OS via migrations 0102/0103, it propagates here
///     without a code change.
///   • Personalised — only specialties the user actually has the permit
///     for show up, so the business card can't accidentally claim a
///     credential the instructor doesn't hold.
///
/// **Data path:**
///   `auth.users.id`
///     → `contact_instructor.auth_user_id` ⇒ `contact_id`
///     → `instructor_skills.instructor_id == contact_id` (the legacy
///        instructors.id and contacts.id are kept identical by the sync
///        trigger in migration 0083)
///     → `skills.id` joined via PostgREST embed, filtered to
///        `category IN ('Specialty', 'SPEI')`.
///
/// **Label hygiene:** the master catalog stores labels with a `"Specialty: "`
/// or `"SPEI: "` prefix so the SkillMatrix UI in the main app can group
/// them. AtollCard pills don't need that prefix — we strip it for display
/// but keep the cleaned label as the *id* persisted on the card so the
/// existing `dive_profile.specialties: [String]` storage stays compatible.
@MainActor
public final class SpecialtyCatalogService {
  public static let shared = SpecialtyCatalogService()
  private static let logger = Logger(subsystem: "swiss.atoll.card", category: "specialty-catalog")

  private init() {}

  // MARK: - Model

  public struct Specialty: Identifiable, Hashable, Sendable {
    /// Stable identifier — the skill code from the master table (e.g.
    /// `spec_deep`, `spei_wreck`). Used for dedup and stable selection.
    public let id: String
    /// Display label, prefix-stripped (e.g. "Deep", "Wreck").
    public let label: String
    /// `"Specialty"` (Instructor-level) or `"SPEI"` (Trainer-level).
    public let category: String

    public var isTrainerLevel: Bool { category == "SPEI" }
  }

  // MARK: - Fetch

  /// Returns the user's specialties, sorted alphabetically by label,
  /// Specialty entries first followed by SPEI. In mock mode returns a
  /// curated set so the editor is never empty during demos.
  public func fetchUserSpecialties() async throws -> [Specialty] {
    if Config.useMockData { return mockSpecialties }

    let client = SupabaseClient.shared
    let session = try await client.auth.session
    let authUserId = session.user.id.uuidString

    // 1. contact_id (== instructor_id thanks to the 0083 sync trigger).
    struct Sidecar: Decodable { let contact_id: String }
    let sidecars: [Sidecar] = try await client
      .from("contact_instructor")
      .select("contact_id")
      .eq("auth_user_id", value: authUserId)
      .limit(1)
      .execute()
      .value
    guard let contactId = sidecars.first?.contact_id else {
      Self.logger.debug("No contact_instructor row for current auth user")
      return []
    }

    // 2. Embed-style join: `select="skills(...)"` follows the FK on
    // instructor_skills.skill_id and inlines the related skill columns.
    struct InstructorSkillRow: Decodable {
      struct SkillEmbed: Decodable {
        let id: String
        let code: String
        let label: String
        let category: String?
      }
      let skills: SkillEmbed
    }

    let rows: [InstructorSkillRow] = try await client
      .from("instructor_skills")
      .select("skills(id, code, label, category)")
      .eq("instructor_id", value: contactId)
      .execute()
      .value

    let specialties = rows
      .map { Specialty(
        id: $0.skills.code,
        label: Self.stripPrefix($0.skills.label),
        category: $0.skills.category ?? ""
      ) }
      .filter { $0.category == "Specialty" || $0.category == "SPEI" }
      // Specialty first, then SPEI; within each tier, alphabetical.
      .sorted {
        if $0.category != $1.category {
          return $0.category == "Specialty"   // Specialty before SPEI
        }
        return $0.label.localizedCompare($1.label) == .orderedAscending
      }

    Self.logger.debug("Loaded \(specialties.count) specialty permits")
    return specialties
  }

  // MARK: - Helpers

  /// Strips the `"Specialty: "` or `"SPEI: "` prefix used in the main app's
  /// SkillMatrix display so the pill label fits on a business card.
  private static func stripPrefix(_ label: String) -> String {
    if label.hasPrefix("Specialty: ") {
      return String(label.dropFirst("Specialty: ".count))
    }
    if label.hasPrefix("SPEI: ") {
      return String(label.dropFirst("SPEI: ".count))
    }
    return label
  }

  // MARK: - Mock data

  /// Curated mock list — matches what Dominik would actually have in
  /// production so the demo card looks credible.
  private let mockSpecialties: [Specialty] = [
    .init(id: "spec_boat",            label: "Boat",                            category: "Specialty"),
    .init(id: "spec_deep",            label: "Deep",                            category: "Specialty"),
    .init(id: "spec_dsmb",            label: "Delayed Surface Marker Buoy",     category: "Specialty"),
    .init(id: "spec_digital_photo",   label: "Digital UW Photography",          category: "Specialty"),
    .init(id: "spec_drift",           label: "Drift",                           category: "Specialty"),
    .init(id: "spec_dry",             label: "Dry Suit",                        category: "Specialty"),
    .init(id: "spec_equipment",       label: "Equipment Specialist",            category: "Specialty"),
    .init(id: "spec_full_face_mask",  label: "Full Face Mask",                  category: "Specialty"),
    .init(id: "spec_naturalist",      label: "Underwater Naturalist",           category: "Specialty"),
    .init(id: "spec_navi",            label: "Underwater Navigator",            category: "Specialty"),
    .init(id: "spec_night",           label: "Night Diver",                     category: "Specialty"),
    .init(id: "spec_nitrox",          label: "Enriched Air",                    category: "Specialty"),
    .init(id: "spec_ppb",             label: "Peak Performance Buoyancy",       category: "Specialty"),
    .init(id: "spec_scooter",         label: "Diver Propulsion Vehicle",        category: "Specialty"),
    .init(id: "spec_search",          label: "Search & Recovery",               category: "Specialty"),
    .init(id: "spec_video",           label: "Underwater Videographer",         category: "Specialty"),
    .init(id: "spec_wreck",           label: "Wreck",                           category: "Specialty"),
    .init(id: "spei_deep",            label: "Deep",                            category: "SPEI"),
    .init(id: "spei_nitrox",          label: "Enriched Air",                    category: "SPEI"),
    .init(id: "spei_wreck",           label: "Wreck",                           category: "SPEI"),
  ]
}
