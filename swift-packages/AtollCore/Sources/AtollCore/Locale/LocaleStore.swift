import Foundation
import Supabase
import AtollCore

@MainActor
@Observable
final class LocaleStore {
  /// Aktuelle Sprache als ISO-Code ("de" oder "en"). Wird zu einem Locale konvertiert
  /// fuer die SwiftUI environment.
  private(set) var languageCode: String = LocaleStore.defaultCode()

  private let supabase = SupabaseClient.shared

  /// SwiftUI Environment-Locale aus dem aktuellen languageCode.
  var locale: Locale { Locale(identifier: languageCode) }

  /// Beim Login: User-Preference aus contact_instructor uebernehmen wenn gesetzt.
  /// Sonst bleibt's beim Device-Default.
  func adoptFromUser(_ user: CurrentUser) {
    if let pref = user.preferredLanguage, ["de", "en"].contains(pref) {
      languageCode = pref
    }
  }

  /// Sprache aendern: optimistic local update + DB-Schreiben.
  /// Rollback bei Fehler.
  func setLanguage(_ code: String, for authUserId: UUID?) async {
    guard ["de", "en"].contains(code) else { return }
    let previous = languageCode
    languageCode = code

    guard let uid = authUserId else { return } // unlinked user — nur lokal

    do {
      struct LangUpdate: Encodable {
        let preferred_language: String
      }
      try await supabase
        .from("contact_instructor")
        .update(LangUpdate(preferred_language: code))
        .eq("auth_user_id", value: uid)
        .execute()
    } catch {
      languageCode = previous
      #if DEBUG
      print("⚠️ LocaleStore.setLanguage failed: \(error)")
      #endif
    }
  }

  /// Device-Locale als Fallback. Wenn Device weder de noch en spricht, default de.
  private static func defaultCode() -> String {
    let device = Locale.current.language.languageCode?.identifier ?? "de"
    return ["de", "en"].contains(device) ? device : "de"
  }
}
