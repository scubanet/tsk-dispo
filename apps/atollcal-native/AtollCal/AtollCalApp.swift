import SwiftUI
import EventKit
import AtollCore

@main
struct AtollCalApp: App {
  @Environment(\.scenePhase) private var scenePhase

  @State private var auth: AuthState
  @State private var localeStore: LocaleStore
  @State private var calendarStore: SystemCalendarStore
  @State private var atollLoader: AtollEventLoader
  @State private var toastCenter: ToastCenter

  init() {
    // MUSS vor State(initialValue: AuthState()) laufen — AuthState.init() greift sofort
    // auf SupabaseClient.shared zu, der die registrierte Config braucht.
    AtollCoreConfig.register(AppSupabaseConfig())
    _auth = State(initialValue: AuthState())
    _localeStore = State(initialValue: LocaleStore())
    _calendarStore = State(initialValue: SystemCalendarStore())
    _atollLoader = State(initialValue: AtollEventLoader())
    _toastCenter = State(initialValue: ToastCenter())
  }

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(auth)
        .environment(localeStore)
        .environment(calendarStore)
        .environment(atollLoader)
        .environment(toastCenter)
        .environment(\.locale, localeStore.locale)
        .toastBanner(from: toastCenter)
        .onOpenURL { url in
          guard url.scheme == "atollcal" else { return }
          Task { try? await auth.handleAuthCallback(url: url) }
        }
        .onChange(of: scenePhase) { _, newPhase in
          if newPhase == .active {
            // Bei App-Foreground: Auth-Status + EventKit-State refreshen,
            // dann globalen EKEventStoreChanged broadcasten damit alle
            // Calendar-Views ihre Events neu laden.
            calendarStore.refreshAuthStatus()
            NotificationCenter.default.post(name: .EKEventStoreChanged, object: nil)
          }
        }
        .preferredColorScheme(nil)
    }
  }
}
