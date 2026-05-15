import SwiftUI
import AtollCore

@main
struct ATOLLApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  @State private var auth: AuthState
  @State private var localeStore: LocaleStore

  init() {
    // Config MUSS registriert sein bevor irgendein Code SupabaseClient.shared
    // anfasst — AuthState.init() greift sofort drauf zu. Daher hier vor
    // State(initialValue:) registrieren.
    AtollCoreConfig.register(AppSupabaseConfig())
    _auth = State(initialValue: AuthState())
    _localeStore = State(initialValue: LocaleStore())
  }

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(auth)
        .environment(localeStore)
        .environment(\.locale, localeStore.locale)
        .onOpenURL { url in
          // Magic-Link callback: atoll://auth/callback?token_hash=...&type=...
          guard url.scheme == "atoll" else { return }
          Task {
            try? await auth.handleAuthCallback(url: url)
          }
        }
        // Push-Manager kennt den eingeloggten Instructor — sodass Tokens der richtigen Person zugeordnet werden.
        .onChange(of: instructorId(from: auth.status)) { _, newId in
          PushManager.shared.currentInstructorId = newId
          if newId != nil {
            // Beim ersten Login: Push-Permission abfragen.
            Task { await PushManager.shared.requestAuthorizationIfNeeded() }
          }
        }
        .onChange(of: userPreferredLanguage(from: auth.status)) { _, _ in
          // Beim Sign-In oder Refresh: locale-Override aus User uebernehmen
          if case .signedIn(let user) = auth.status {
            localeStore.adoptFromUser(user)
          }
        }
        .preferredColorScheme(nil) // System (light/dark/auto)
    }
  }

  private func instructorId(from status: AuthState.Status) -> UUID? {
    if case .signedIn(let user) = status { return user.legacyInstructorId }
    return nil
  }

  /// Wird als Schluessel fuer onChange genutzt — nil wenn signedOut, sonst der prefLang.
  private func userPreferredLanguage(from status: AuthState.Status) -> String? {
    if case .signedIn(let user) = status { return user.preferredLanguage ?? "" }
    return nil
  }
}
