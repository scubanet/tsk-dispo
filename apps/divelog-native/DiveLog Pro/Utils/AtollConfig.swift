import Foundation
import AtollCore

// ═══════════════════════════════════════
// MARK: - Atoll / Supabase configuration
// ═══════════════════════════════════════
//
// Phase 2 der Atoll-Integration (Iteration 1). Gleiches Supabase-Projekt wie
// ComHub & Co. Der anonKey ist öffentlich (Client-Apps) — RLS sichert die
// Daten serverseitig.

enum AtollConfig {
    static let supabaseURL     = URL(string: "https://axnrilhdokkfujzjifhj.supabase.co")!
    static let supabaseAnonKey = "sb_publishable_qNhMQ7GMfvtkZgZ78e4kOw_3YOLcrwv"
    static let authRedirectURL = URL(string: "divelog://auth/callback")!
}

/// AtollCore-Konformität — verbindet die Config mit dem geteilten
/// Supabase-Client (`SupabaseClient.shared`). Registrierung erfolgt in
/// `DiveLogProApp.init()` via `AtollCoreConfig.register(...)`.
struct DiveLogSupabaseConfig: SupabaseConfig {
    var supabaseURL: URL        { AtollConfig.supabaseURL }
    var supabaseAnonKey: String { AtollConfig.supabaseAnonKey }
    var authRedirectURL: URL    { AtollConfig.authRedirectURL }
}
