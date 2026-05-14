import Foundation
import Supabase

@MainActor
@Observable
final class IntakeStore {
  enum LoadState {
    case idle, loading, loaded, error
  }

  /// Intakes keyed by `course_participant_id` für schnelles Lookup in der View.
  private(set) var intakesByParticipant: [UUID: IntakeChecklist] = [:]
  private(set) var loadState: LoadState = .idle
  private(set) var errorMessage: String?

  private let supabase = SupabaseClient.shared

  /// Lädt alle bestehenden Intakes für eine Liste von course_participant_ids.
  /// Nicht existierende Intakes erscheinen einfach nicht im Dictionary.
  func load(participantIds: [UUID]) async {
    guard !participantIds.isEmpty else {
      intakesByParticipant = [:]
      loadState = .loaded
      return
    }
    loadState = .loading
    errorMessage = nil
    do {
      let rows: [IntakeChecklist] = try await supabase
        .from("intake_checklists")
        .select("id, course_participant_id, medical_signed, liability_signed, safe_diving_signed, notes, checked_on, checked_by_id")
        .in("course_participant_id", values: participantIds.map(\.uuidString))
        .execute()
        .value

      intakesByParticipant = Dictionary(uniqueKeysWithValues: rows.compactMap { row in
        guard let cpid = row.courseParticipantId else { return nil }
        return (cpid, row)
      })
      loadState = .loaded
    } catch {
      #if DEBUG
      print("⚠️ IntakeStore.load failed: \(error)")
      #endif
      loadState = .error
      errorMessage = error.localizedDescription
    }
  }

  /// Speichert Pre-Dive-Intake. Existiert noch keine Row: INSERT. Sonst UPDATE.
  /// Aktualisiert das lokale Dictionary erst NACH erfolgreichem Save.
  func save(
    participantId: UUID,
    medical: Bool,
    liability: Bool,
    safeDiving: Bool,
    notes: String?,
    checkedById: UUID?
  ) async throws {
    let today = Self.isoDateFormatter.string(from: Date())
    let payload = IntakeUpsert(
      courseParticipantId: participantId,
      medicalSigned: medical,
      liabilitySigned: liability,
      safeDivingSigned: safeDiving,
      notes: notes,
      checkedOn: today,
      checkedById: checkedById
    )

    let saved: IntakeChecklist
    if let existing = intakesByParticipant[participantId], let id = existing.id {
      saved = try await supabase
        .from("intake_checklists")
        .update(payload)
        .eq("id", value: id)
        .select()
        .single()
        .execute()
        .value
    } else {
      saved = try await supabase
        .from("intake_checklists")
        .insert(payload)
        .select()
        .single()
        .execute()
        .value
    }

    intakesByParticipant[participantId] = saved
  }

  private static let isoDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(identifier: "Europe/Zurich")
    return f
  }()
}
