import Foundation
import Supabase
import AtollCore

@MainActor
@Observable
final class ParticipantsStore {
  enum LoadState {
    case idle, loading, loaded, error
  }

  private(set) var participants: [CourseParticipant] = []
  private(set) var loadState: LoadState = .idle
  private(set) var errorMessage: String?

  private let supabase = SupabaseClient.shared

  func load(courseId: UUID) async {
    loadState = .loading
    errorMessage = nil
    do {
      let result: [CourseParticipant] = try await supabase
        .from("course_participants")
        .select("id, course_id, student_id, status, certificate_nr, notes, student:contacts!inner(id, first_name, last_name, primary_email, contact_student(level, photo_url))")
        .eq("course_id", value: courseId)
        .execute()
        .value

      participants = result.sorted {
        ($0.student?.lastName ?? "") < ($1.student?.lastName ?? "")
      }
      loadState = .loaded
    } catch {
      #if DEBUG
      print("⚠️ ParticipantsStore.load(\(courseId)) failed: \(error)")
      #endif
      if !participants.isEmpty {
        loadState = .loaded
      } else {
        loadState = .error
        errorMessage = error.localizedDescription
      }
    }
  }
}
