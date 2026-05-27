import SwiftUI
import EventKit
import AtollCore
import OSLog

@main
struct AtollCalApp: App {
  @Environment(\.scenePhase) private var scenePhase

  @State private var auth: AuthState
  @State private var localeStore: LocaleStore
  @State private var calendarStore: SystemCalendarStore
  @State private var atollLoader: AtollEventLoader
  @State private var toastCenter: ToastCenter
  @State private var weatherStore: WeatherStore
  @State private var anniversaryStore: ContactsAnniversaryStore

  private static let logger = Logger(subsystem: "swiss.atoll.cal", category: "app")

  /// Forces `AtollCoreConfig.register(...)` to run before any `State` property
  /// is initialised in `init()`. `AuthState.init()` reaches into
  /// `SupabaseClient.shared` which needs the registered config — without this
  /// bootstrap, a future refactor that reorders the `_property = State(...)`
  /// assignments above the explicit register call would crash at launch.
  ///
  /// `static let` initialisers are thread-safe and run exactly once on first
  /// access. The `_ = Self.bootstrap` line at the top of `init()` guarantees
  /// that first access happens before any other property work in `init()`.
  private static let bootstrap: Void = {
    AtollCoreConfig.register(AppSupabaseConfig())
    return ()
  }()

  init() {
    _ = Self.bootstrap
    _auth = State(initialValue: AuthState())
    _localeStore = State(initialValue: LocaleStore())
    _calendarStore = State(initialValue: SystemCalendarStore())
    _atollLoader = State(initialValue: AtollEventLoader())
    _toastCenter = State(initialValue: ToastCenter())
    _weatherStore = State(initialValue: WeatherStore())
    _anniversaryStore = State(initialValue: ContactsAnniversaryStore())
  }

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(auth)
        .environment(localeStore)
        .environment(calendarStore)
        .environment(atollLoader)
        .environment(toastCenter)
        .environment(weatherStore)
        .environment(anniversaryStore)
        .environment(\.locale, localeStore.locale)
        .toastBanner(from: toastCenter)
        .task {
          // GL-006 Phase 1.5d: pull the daily forecast for the agenda window
          // on launch so the day-bucket headers can render weather inline.
          await weatherStore.refreshIfNeeded()
          // GL-006 Phase 1.5h: Apple's EventKit Birthday-calendar only
          // mirrors birthdays, not anniversaries. Pull anniversaries via the
          // Contacts framework — first time triggers the system permission
          // prompt; subsequent runs reuse the cached authorisation.
          await anniversaryStore.requestAccess()
          await anniversaryStore.refresh()
        }
        .onOpenURL { url in
          guard url.scheme == "atollcal" else { return }
          Task { @MainActor in
            do {
              try await auth.handleAuthCallback(url: url)
            } catch {
              Self.logger.error("handleAuthCallback failed: \(error.localizedDescription, privacy: .public)")
              toastCenter.show(
                String(localized: "Anmelde-Link konnte nicht eingelöst werden — bitte neuen Link anfordern."),
                kind: .error
              )
            }
          }
        }
        .onChange(of: scenePhase) { _, newPhase in
          if newPhase == .active {
            // Bei App-Foreground: Auth-Status + EventKit-State refreshen,
            // dann globalen EKEventStoreChanged broadcasten damit alle
            // Calendar-Views ihre Events neu laden.
            calendarStore.refreshAuthStatus()
            NotificationCenter.default.post(name: .EKEventStoreChanged, object: nil)
            // Refresh weather if it's stale (30 min throttle inside the store).
            Task { await weatherStore.refreshIfNeeded() }
            // Refresh anniversaries — contact details may have changed in
            // the system Contacts app while we were backgrounded.
            Task { await anniversaryStore.refresh() }
          }
        }
        .preferredColorScheme(nil)
    }

    #if os(macOS)
    // Standard macOS Settings scene — wires ⌘, to the proper Settings window
    // (instead of an in-window sheet) and matches the "AtollCal → Settings…"
    // menu item users expect on macOS.
    Settings {
      SettingsView()
        .environment(auth)
        .environment(localeStore)
        .environment(calendarStore)
        .environment(atollLoader)
        .environment(toastCenter)
        .environment(\.locale, localeStore.locale)
    }
    #endif
  }
}
