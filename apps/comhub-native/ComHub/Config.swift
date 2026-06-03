import Foundation
import AtollCore

/// Supabase-Konfiguration. `anonKey` ist öffentlich (Client-Apps) — RLS sichert die Daten.
enum Config {
  static let supabaseURL     = URL(string: "https://axnrilhdokkfujzjifhj.supabase.co")!
  static let supabaseAnonKey = "sb_publishable_qNhMQ7GMfvtkZgZ78e4kOw_3YOLcrwv"
  static let authRedirectURL = URL(string: "comhub://auth/callback")!
  static let appName    = "ComHub"
  static let tenantName = "TSK Zürich"
}

/// AtollCore-Konformität — verbindet Config mit dem geteilten Supabase-Client.
struct AppSupabaseConfig: SupabaseConfig {
  var supabaseURL: URL        { Config.supabaseURL }
  var supabaseAnonKey: String { Config.supabaseAnonKey }
  var authRedirectURL: URL    { Config.authRedirectURL }
}
