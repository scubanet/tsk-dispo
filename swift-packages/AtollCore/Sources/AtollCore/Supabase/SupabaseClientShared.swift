import Foundation
import Supabase

extension SupabaseClient {
  /// App-weiter Singleton, initialisiert aus der registrierten AtollCoreConfig.
  ///
  /// `emitLocalSessionAsInitialSession: true` opt-in für das neue (korrekte)
  /// Verhalten — siehe https://github.com/supabase/supabase-swift/pull/822
  /// Damit verschwindet die Deprecation-Warning beim App-Start.
  public static let shared: SupabaseClient = {
    let config = AtollCoreConfig.current
    return SupabaseClient(
      supabaseURL: config.supabaseURL,
      supabaseKey: config.supabaseAnonKey,
      options: SupabaseClientOptions(
        auth: SupabaseClientOptions.AuthOptions(
          emitLocalSessionAsInitialSession: true
        )
      )
    )
  }()
}
