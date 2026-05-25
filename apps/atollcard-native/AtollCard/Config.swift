import Foundation
import AtollCore

/// AtollCard runtime configuration.
///
/// `supabaseURL` / `supabaseAnonKey` are intentionally the same values as
/// `AtollCal` — the apps share the Atoll OS Supabase project so cards,
/// people, courses and contacts all live in one schema. The anon key is
/// public by design (client apps), RLS guards the data.
enum Config {
  // MARK: – Supabase
  static let supabaseURL     = URL(string: "https://axnrilhdokkfujzjifhj.supabase.co")!
  static let supabaseAnonKey = "sb_publishable_qNhMQ7GMfvtkZgZ78e4kOw_3YOLcrwv"

  /// Direct URL to the wallet-pass Edge Function on Supabase.
  /// (Don't route through atoll-os.com — the function lives on the
  /// Supabase Functions hostname.)
  static let walletPassEndpoint = URL(
    string: "\(supabaseURL.absoluteString)/functions/v1/atollcard-wallet-pass"
  )!

  // MARK: – Auth
  static let authRedirectURL = URL(string: "atollcard://auth/callback")!

  // MARK: – Branding
  static let appName    = "AtollCard"
  static let tenantName = "TSK Zürich"

  // MARK: – Public card URLs
  /// Base URL for the public-facing card page rendered by Atoll OS web.
  /// `https://atoll-os.com/c/<slug>` — the slug is the QR payload.
  static let publicCardBaseURL = URL(string: "https://atoll-os.com/c")!

  // MARK: – Development flags
  /// When true, all repositories return seeded mock data — no Supabase
  /// round-trip. Flip this to false once the schema is migrated and the
  /// app is wired up to real cards. Defaults to true so the app boots
  /// with realistic demo content on day 1.
  static let useMockData = false
}

/// AtollCore conformance — connects `Config` to the shared Supabase client.
struct AppSupabaseConfig: SupabaseConfig {
  var supabaseURL: URL        { Config.supabaseURL }
  var supabaseAnonKey: String { Config.supabaseAnonKey }
  var authRedirectURL: URL    { Config.authRedirectURL }
}
