import Foundation

/// Supabase Konfiguration.
///
/// Werte sind dieselben wie in `apps/web/.env.production`.
/// Der `anonKey` ist öffentlich (designed für Client-Apps) — RLS auf der DB sichert die Daten.
enum Config {
  // MARK: – Supabase
  static let supabaseURL = URL(string: "https://axnrilhdokkfujzjifhj.supabase.co")!
  static let supabaseAnonKey = "sb_publishable_qNhMQ7GMfvtkZgZ78e4kOw_3YOLcrwv"

  // MARK: – Auth
  /// Custom URL scheme für Magic-Link-Callback. Muss in Supabase Auth → Redirect URLs erlaubt sein.
  static let authRedirectURL = URL(string: "atoll://auth/callback")!

  // MARK: – Branding
  static let appName = "ATOLL"
  static let appTagline = "The diving school OS"
  static let tenantName = "TSK Zürich"
}
