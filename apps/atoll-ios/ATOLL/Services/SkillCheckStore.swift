import Foundation
import Supabase
import AtollCore

@MainActor
@Observable
final class SkillCheckStore {
  enum LoadState {
    case idle, loading, loaded, error
  }

  private(set) var definitions: [SkillDefinition] = []
  private(set) var recordsByKey: [String: SkillRecord] = [:]
  /// Pro Skill das aktuelle Datum (das auch beim Tap auf einen Chip verwendet wird).
  /// Beim Load aus dem ersten existierenden Record gefüllt, sonst Default heute.
  private(set) var dateBySkill: [String: String] = [:]
  private(set) var loadState: LoadState = .idle
  private(set) var errorMessage: String?

  /// Per-key in-flight guard. Schluckt redundante Tap-Events während eine
  /// Toggle-Call gerade läuft — verhindert Double-Tap-Race der lokal id:nil
  /// Records korrumpiert.
  private var inFlight: Set<String> = []

  private let supabase = SupabaseClient.shared

  func loadDefinitions(courseTypeCode: String) async {
    do {
      let rows: [SkillDefinition] = try await supabase
        .from("skill_definitions")
        .select("id, course_type_code, skill_code, section, label_de, label_en, display_order")
        .eq("course_type_code", value: courseTypeCode)
        .order("display_order", ascending: true)
        .execute()
        .value
      definitions = rows
    } catch {
      #if DEBUG
      print("⚠️ SkillCheckStore.loadDefinitions failed: \(error)")
      #endif
      errorMessage = error.localizedDescription
      loadState = .error
    }
  }

  func loadRecords(courseId: UUID) async {
    loadState = .loading
    errorMessage = nil
    do {
      let rows: [SkillRecord] = try await supabase
        .from("padi_skill_records")
        .select("id, course_id, participant_id, skill_code, completed_on, instructor_id")
        .eq("course_id", value: courseId)
        .execute()
        .value

      recordsByKey = Dictionary(uniqueKeysWithValues: rows.map {
        (Self.key(participantId: $0.participantId, skillCode: $0.skillCode), $0)
      })
      // Per-skill date: nimm das erste gefundene completed_on. Bei korrektem
      // Sync sind eh alle Records einer Skill auf demselben Datum.
      var dates: [String: String] = [:]
      for record in rows {
        if let date = record.completedOn {
          dates[record.skillCode] = date
        }
      }
      dateBySkill = dates
      loadState = .loaded
    } catch {
      #if DEBUG
      print("⚠️ SkillCheckStore.loadRecords failed: \(error)")
      #endif
      loadState = .error
      errorMessage = error.localizedDescription
    }
  }

  func toggle(
    courseId: UUID,
    participantId: UUID,
    skillCode: String,
    instructorId: UUID?
  ) async {
    let key = Self.key(participantId: participantId, skillCode: skillCode)
    guard !inFlight.contains(key) else {
      // Schlucke redundanten Tap solange ein anderer Toggle für diese
      // (Skill, Teilnehmer) noch läuft. Verhindert id:nil-Korruption.
      return
    }
    inFlight.insert(key)
    defer { inFlight.remove(key) }

    let previous = recordsByKey[key]
    let dateForRecord = dateBySkill[skillCode] ?? Self.todayIsoDate()

    // Optimistic: toggle local state first.
    if previous != nil {
      recordsByKey.removeValue(forKey: key)
    } else {
      recordsByKey[key] = SkillRecord(
        id: nil,
        courseId: courseId,
        participantId: participantId,
        skillCode: skillCode,
        completedOn: dateForRecord,
        instructorId: instructorId
      )
      // Beim ersten Record für eine Skill setzen wir dateBySkill, damit der
      // Date-Pill in der UI sofort den Default zeigt.
      if dateBySkill[skillCode] == nil {
        dateBySkill[skillCode] = dateForRecord
      }
    }

    do {
      if let prev = previous, let id = prev.id {
        try await supabase
          .from("padi_skill_records")
          .delete()
          .eq("id", value: id)
          .execute()
      } else {
        let payload = SkillRecordInsert(
          courseId: courseId,
          participantId: participantId,
          skillCode: skillCode,
          completedOn: dateForRecord,
          instructorId: instructorId
        )
        let inserted: SkillRecord = try await supabase
          .from("padi_skill_records")
          .insert(payload)
          .select()
          .single()
          .execute()
          .value
        recordsByKey[key] = inserted
      }
      errorMessage = nil
    } catch {
      if let prev = previous {
        recordsByKey[key] = prev
      } else {
        recordsByKey.removeValue(forKey: key)
      }
      #if DEBUG
      print("⚠️ SkillCheckStore.toggle failed: \(error)")
      #endif
      errorMessage = error.localizedDescription
    }
  }

  func isDone(participantId: UUID, skillCode: String) -> Bool {
    recordsByKey[Self.key(participantId: participantId, skillCode: skillCode)] != nil
  }

  /// Aktuelles Datum für einen Skill (für Anzeige im Pill und Default bei Toggle).
  /// Fällt auf heute zurück wenn noch keine Records existieren.
  func dateForSkill(_ skillCode: String) -> String {
    dateBySkill[skillCode] ?? Self.todayIsoDate()
  }

  /// Mass-UPDATE aller bestehenden Records für (course, skill) auf ein neues Datum.
  /// Setzt zusätzlich `dateBySkill[skillCode]`, damit neue Toggle-Aktionen das Datum übernehmen.
  /// Optimistic mit Rollback bei Fehler.
  func updateDateForSkill(courseId: UUID, skillCode: String, newDate: String) async {
    let previousDate = dateBySkill[skillCode]
    let previousRecords = recordsByKey

    // Optimistic local update
    dateBySkill[skillCode] = newDate
    for (key, record) in recordsByKey where record.skillCode == skillCode {
      recordsByKey[key] = SkillRecord(
        id: record.id,
        courseId: record.courseId,
        participantId: record.participantId,
        skillCode: record.skillCode,
        completedOn: newDate,
        instructorId: record.instructorId
      )
    }

    do {
      struct DateUpdate: Encodable {
        let completed_on: String
      }
      try await supabase
        .from("padi_skill_records")
        .update(DateUpdate(completed_on: newDate))
        .eq("course_id", value: courseId)
        .eq("skill_code", value: skillCode)
        .execute()
      errorMessage = nil
    } catch {
      // Rollback
      dateBySkill[skillCode] = previousDate
      recordsByKey = previousRecords
      #if DEBUG
      print("⚠️ SkillCheckStore.updateDateForSkill failed: \(error)")
      #endif
      errorMessage = error.localizedDescription
    }
  }

  private static func todayIsoDate() -> String {
    isoDateFormatter.string(from: Date())
  }

  private static func key(participantId: UUID, skillCode: String) -> String {
    "\(participantId.uuidString)-\(skillCode)"
  }

  private static let isoDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(identifier: "Europe/Zurich")
    return f
  }()
}
