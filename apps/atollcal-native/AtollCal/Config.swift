import Foundation
import AtollCore

/// Supabase Konfiguration.
///
/// Werte sind dieselben wie in `apps/web/.env.production` und `apps/atoll-ios`.
/// Der `anonKey` ist öffentlich (designed für Client-Apps) — RLS auf der DB sichert die Daten.
enum Config {
  // MARK: – Supabase
  static let supabaseURL     = URL(string: "https://axnrilhdokkfujzjifhj.supabase.co")!
  static let supabaseAnonKey = "sb_publishable_qNhMQ7GMfvtkZgZ78e4kOw_3YOLcrwv"

  // MARK: – Auth
  /// Custom URL scheme für Magic-Link-Callback. Muss in Supabase Auth → Redirect URLs erlaubt sein.
  static let authRedirectURL = URL(string: "atollcal://auth/callback")!

  // MARK: – Branding
  static let appName    = "AtollCal"
  static let tenantName = "TSK Zürich"
}

/// AtollCore-Konformität — verbindet Config mit dem geteilten Supabase-Client.
struct AppSupabaseConfig: SupabaseConfig {
  var supabaseURL: URL        { Config.supabaseURL }
  var supabaseAnonKey: String { Config.supabaseAnonKey }
  var authRedirectURL: URL    { Config.authRedirectURL }
}
