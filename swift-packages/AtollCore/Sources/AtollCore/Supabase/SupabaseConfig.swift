// SupabaseConfig — App-spezifische Supabase-URL + Anon-Key.
//
// Jede ATOLL-App (atoll-ios, atollcal-native, ...) liefert ihre eigene
// SupabaseConfig-Implementation, damit AtollCore.shared den richtigen
// Client bauen kann.

import Foundation

public protocol SupabaseConfig {
  var supabaseURL: URL { get }
  var supabaseAnonKey: String { get }
  /// Custom URL scheme für Magic-Link-Callback (z.B. atoll://auth/callback).
  var authRedirectURL: URL { get }
}

/// App muss vor erstem Zugriff auf SupabaseClient.shared ihre Config registrieren.
public enum AtollCoreConfig {
  nonisolated(unsafe) private static var _config: SupabaseConfig?

  public static func register(_ config: SupabaseConfig) {
    _config = config
  }

  internal static var current: SupabaseConfig {
    guard let c = _config else {
      preconditionFailure("AtollCoreConfig.register(...) must be called before accessing SupabaseClient.shared")
    }
    return c
  }
}
