import SwiftUI
import AtollCore
import AtollHub
import EventKit
import OSLog

@main
struct ComHubApp: App {
  @Environment(\.scenePhase) private var scenePhase

  @State private var auth: AuthState
  @State private var localeStore: LocaleStore
  @State private var hub: Hub
  @State private var appleAuth: AppleAuthorizationService
  @State private var eventStore = EKEventStore()

  #if os(iOS)
  @UIApplicationDelegateAdaptor(PushAppDelegate.self) private var pushDelegate
  #elseif os(macOS)
  @NSApplicationDelegateAdaptor(PushAppDelegate.self) private var pushDelegate
  #endif

  private static let logger = Logger(subsystem: "swiss.atoll.hub", category: "app")

  /// Erzwingt `AtollCoreConfig.register(...)` vor jeder `State`-Initialisierung —
  /// siehe swift-packages/README.md (AuthState.init greift sofort auf
  /// SupabaseClient.shared zu, das die Config braucht).
  private static let bootstrap: Void = {
    AtollCoreConfig.register(AppSupabaseConfig())
    return ()
  }()

  init() {
    _ = Self.bootstrap
    _auth = State(initialValue: AuthState())
    _localeStore = State(initialValue: LocaleStore())
    _hub = State(initialValue: Hub())
    _appleAuth = State(initialValue: AppleAuthorizationService())
  }

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(auth)
        .environment(localeStore)
        .environment(hub)
        .environment(appleAuth)
        .environment(\.locale, localeStore.locale)
        .task {
          // Apple-Berechtigungen beim ersten Start anfragen (System-Dialoge).
          await appleAuth.requestAll()
        }
        .onOpenURL { url in
          guard url.scheme == "comhub" else { return }
          Task { @MainActor in
            do { try await auth.handleAuthCallback(url: url) }
            catch { Self.logger.error("handleAuthCallback failed: \(error.localizedDescription, privacy: .public)") }
          }
        }
        .onChange(of: scenePhase) { _, newPhase in
          if newPhase == .active { appleAuth.refreshStatus() }
        }
        .onChange(of: authStatusKey) { _, _ in
          if case .signedIn(let user) = auth.status {
            HubWiring.connectAll(into: hub, currentUser: user, eventStore: eventStore)
            PushService.shared.authUserId = user.authUserId
          } else {
            hub.reset()
            PushService.shared.authUserId = nil
          }
        }
        .task(id: authStatusKey) {
          if case .signedIn(let user) = auth.status {
            HubWiring.connectAll(into: hub, currentUser: user, eventStore: eventStore)
            PushService.shared.authUserId = user.authUserId
          }
        }
    }
  }

  /// Stabiler Schluessel, der nur bei echtem Statuswechsel kippt (fuer `onChange`/`task(id:)`).
  private var authStatusKey: String {
    switch auth.status {
    case .loading:   return "loading"
    case .signedOut: return "signedOut"
    case .signedIn(let u): return "signedIn:\(u.id.uuidString)"
    }
  }
}
