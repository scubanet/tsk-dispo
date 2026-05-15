import SwiftUI
import AtollCore

@main
struct AtollCalApp: App {
  @State private var auth: AuthState
  @State private var localeStore: LocaleStore
  @State private var calendarStore: SystemCalendarStore

  init() {
    // MUSS vor State(initialValue: AuthState()) laufen — AuthState.init() greift sofort
    // auf SupabaseClient.shared zu, der die registrierte Config braucht.
    AtollCoreConfig.register(AppSupabaseConfig())
    _auth = State(initialValue: AuthState())
    _localeStore = State(initialValue: LocaleStore())
    _calendarStore = State(initialValue: SystemCalendarStore())
  }

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(auth)
        .environment(localeStore)
        .environment(calendarStore)
        .environment(\.locale, localeStore.locale)
        .onOpenURL { url in
          guard url.scheme == "atollcal" else { return }
          Task { try? await auth.handleAuthCallback(url: url) }
        }
        .preferredColorScheme(nil)
    }
  }
}
