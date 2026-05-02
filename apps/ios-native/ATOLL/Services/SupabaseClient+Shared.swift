import Foundation
import Supabase

extension SupabaseClient {
  /// App-weiter Singleton, initialisiert aus `Config`.
  ///
  /// `emitLocalSessionAsInitialSession: true` opt-in für das neue (korrekte)
  /// Verhalten — siehe https://github.com/supabase/supabase-swift/pull/822
  /// Damit verschwindet die Deprecation-Warning beim App-Start.
  static let shared: SupabaseClient = {
    SupabaseClient(
      supabaseURL: Config.supabaseURL,
      supabaseKey: Config.supabaseAnonKey,
      options: SupabaseClientOptions(
        auth: SupabaseClientOptions.AuthOptions(
          emitLocalSessionAsInitialSession: true
        )
      )
    )
  }()
}
