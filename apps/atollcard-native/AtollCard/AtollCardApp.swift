import SwiftUI
import AtollCore
import OSLog
import Supabase

/// AtollCard — digital business cards with lead capture, part of the Atoll OS
/// ecosystem (Atoll OS web, AtollCal, AtollLog, AtollCard).
///
/// Architecture overview (see CHANGELOG.md for the long version):
///   • SwiftUI + @Observable, Swift 6 strict concurrency
///   • Repository pattern — `CardRepository` / `LeadRepository` protocols are
///     hot-swappable: dev runs `MockCardRepository`, prod uses the Supabase
///     implementation (TODO P2).
///   • Reuses `AtollCore.AuthState` + `SupabaseClient.shared` so the user
///     stays logged in across AtollCal / AtollCard with the same magic-link
///     session.
///   • Reuses `AtollDesign.BrandColors` for the persona gradient palette.
@main
struct AtollCardApp: App {
  @Environment(\.scenePhase) private var scenePhase
  @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  @State private var auth: AuthState
  @State private var cardStore: CardStore
  @State private var leadStore: LeadStore
  @State private var analyticsStore: AnalyticsStore
  @State private var toastCenter: ToastCenter

  private static let logger = Logger(subsystem: "swiss.atoll.card", category: "app")

  /// Same trick as AtollCalApp — register the shared Supabase config before
  /// any `@State` initialiser runs, otherwise `AuthState.init()` would touch
  /// `SupabaseClient.shared` with a missing config.
  private static let bootstrap: Void = {
    AtollCoreConfig.register(AppSupabaseConfig())
    return ()
  }()

  init() {
    _ = Self.bootstrap
    let mockMode = Config.useMockData
    _auth = State(initialValue: AuthState())
    _cardStore = State(initialValue: CardStore(
      repository: mockMode ? MockCardRepository() : SupabaseCardRepository()
    ))
    _leadStore = State(initialValue: LeadStore(
      repository: mockMode ? MockLeadRepository() : SupabaseLeadRepository()
    ))
    _analyticsStore = State(initialValue: AnalyticsStore(
      repository: mockMode ? MockAnalyticsRepository() : SupabaseAnalyticsRepository()
    ))
    _toastCenter = State(initialValue: ToastCenter())
  }

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(auth)
        .environment(cardStore)
        .environment(leadStore)
        .environment(analyticsStore)
        .environment(toastCenter)
        .toastBanner(from: toastCenter)
        .task {
          await cardStore.refresh()
          await leadStore.refresh()
          await analyticsStore.refresh()

          // Hand card titles into LeadStore so realtime notifications
          // can render "PADI Course Director · IDC Anfrage" alongside the
          // lead's name. Re-runs whenever cards refresh (the closure is
          // captured by reference, the dict is replaced).
          leadStore.setCardTitles(
            Dictionary(uniqueKeysWithValues: cardStore.cards.map { ($0.id, $0.title) })
          )

          // Live updates — new web leads arrive without pull-to-refresh
          // and trigger a local notification.
          leadStore.startRealtime()

          // Ask for notification permission once (only if not asked yet).
          if await NotificationService.shared.ensureAuthorization() {
            // Register for remote-push so the APNs Auth Key (when configured
            // server-side, see README "Phase 6") can deliver pushes even
            // when the app is closed.
            PushTokenService.shared.register()
          }
        }
        .onOpenURL { url in
          // atollcard://auth/callback?token=...  → Supabase magic-link return
          // atollcard://card/<slug>              → deep-link to a specific card
          Task { await handleDeepLink(url) }
        }
        .onChange(of: scenePhase) { _, newPhase in
          if newPhase == .active {
            Task {
              await leadStore.refresh()  // fresh leads when foregrounding
            }
          }
        }
        // Widget snapshot: clear App-Group file on logout so the Lock-Screen
        // widget falls back to the "Karte einrichten" state instead of
        // showing a stranger's card. Plan called for `.task(id: auth.session?.user.id)`
        // but `AuthState` exposes `.status` (no public `session`), so we
        // derive the auth-user-id from the enum case.
        .task(id: currentAuthUserId) {
          if currentAuthUserId == nil {
            SharedCardSnapshotWriter.write(nil)
          }
        }
    }
  }

  /// Auth user ID derived from `AuthState.status`. Used as the `id:` on the
  /// snapshot-clearing `.task` modifier so the widget file is wiped whenever
  /// the user signs out or switches accounts. `CurrentUser.authUserId` is
  /// itself `UUID?` (unlinked accounts can be missing it), so we flatten
  /// here to a single optional.
  private var currentAuthUserId: UUID? {
    if case let .signedIn(currentUser) = auth.status {
      return currentUser.authUserId
    }
    return nil
  }

  @MainActor
  private func handleDeepLink(_ url: URL) async {
    Self.logger.debug("deep link: \(url.absoluteString, privacy: .public)")

    // Widget-Deep-Link: atollcard://card/<slug>/qr → Fullscreen-QR
    //
    // `url.pathComponents` for `atollcard://card/dominik-cd/qr` is
    // `["/", "dominik-cd", "qr"]` (Apple-Quirk: first element is "/"). The
    // host carries the "card" segment; we only need to read slug + trailing
    // "qr" off the path. Defensive count-check before indexing.
    if url.scheme == "atollcard",
       url.host == "card",
       url.pathComponents.count >= 3,
       url.pathComponents.last == "qr" {
      let slug = url.pathComponents[1]   // skip the leading "/"
      // Wait briefly for CardStore to load if it's still hydrating —
      // a tap on the Lock-Screen widget while the app is cold-launching
      // can hit `cards == []` for a beat before `refresh()` completes.
      for _ in 0..<10 {
        if let card = cardStore.cards.first(where: { $0.slug == slug }) {
          cardStore.presentingFullscreenQR = card
          return
        }
        try? await Task.sleep(nanoseconds: 200_000_000)  // 200ms
      }
      Self.logger.debug("widget deep link: no card found for slug \(slug, privacy: .public)")
      return
    }

    guard url.host == "auth" else { return }

    // Supabase 2.x switched the magic-link callback to PKCE flow — the URL
    // arrives as `atollcard://auth/callback?code=<uuid>`. The older
    // `auth.session(from: url)` path AtollCore uses sometimes silently
    // returns the *previous* session instead of exchanging the new code,
    // which leaves us authenticated as a stale user (RLS returns 0 rows).
    //
    // Explicit fix: pull the `code` out of the URL and call
    // `exchangeCodeForSession` directly, then run the AtollCore
    // user-loading step manually.
    if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
       let code = components.queryItems?.first(where: { $0.name == "code" })?.value {
      do {
        let session = try await SupabaseClient.shared.auth
          .exchangeCodeForSession(authCode: code)
        Self.logger.debug("auth code exchanged for user \(session.user.id, privacy: .public)")
        await auth.bootstrap()   // re-loads CurrentUser with the fresh JWT
      } catch {
        Self.logger.error("code exchange failed: \(error.localizedDescription, privacy: .public)")
      }
      return
    }

    // Fallback for any non-PKCE-shaped magic links.
    do {
      try await auth.handleAuthCallback(url: url)
    } catch {
      Self.logger.error("auth callback failed: \(error.localizedDescription, privacy: .public)")
    }
  }
}
