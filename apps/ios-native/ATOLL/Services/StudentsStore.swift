import Foundation
import Supabase

@MainActor
@Observable
final class StudentsStore {
  enum LoadState {
    case idle, loading, loaded, error
  }

  private(set) var allStudents: [Student] = []
  private(set) var loadState: LoadState = .idle
  private(set) var errorMessage: String?

  private let supabase = SupabaseClient.shared

  /// Lädt alle `contacts` mit `contact_student!inner`-Sidecar (= alle Schüler).
  /// Sortiert nach Last-Name aufsteigend.
  func loadAll() async {
    loadState = .loading
    errorMessage = nil
    do {
      let rows: [Student] = try await supabase
        .from("contacts")
        .select("id, first_name, last_name, primary_email, contact_student!inner(level, photo_url)")
        .eq("kind", value: "person")
        .order("last_name", ascending: true)
        .execute()
        .value
      allStudents = rows
      loadState = .loaded
    } catch {
      #if DEBUG
      print("⚠️ StudentsStore.loadAll failed: \(error)")
      #endif
      loadState = .error
      errorMessage = error.localizedDescription
    }
  }

  /// Client-side Volltextsuche über first_name + last_name + email.
  /// Case-insensitive, Substring-Match. Bei leerem Query: alle Schüler.
  func search(_ query: String) -> [Student] {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !trimmed.isEmpty else { return allStudents }
    return allStudents.filter { s in
      s.firstName.lowercased().contains(trimmed)
        || s.lastName.lowercased().contains(trimmed)
        || (s.primaryEmail?.lowercased().contains(trimmed) ?? false)
    }
  }
}
