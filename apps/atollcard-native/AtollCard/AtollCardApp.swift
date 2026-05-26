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

  // Offline-queue infrastructure (Welle D — Phase D wiring). The cache is
  // constructed once per app launch in `init()` so the same instance is shared
  // by the drainer and (Task 12) the Cached* repository decorators — SwiftData
  // expects exactly one `ModelContainer` per schema/URL across the process.
  // `try?` because container-init throws on schema mismatch; if it ever does
  // we degrade gracefully to direct-to-Supabase (no cache, no queue) rather
  // than crashing.
  @State private var cacheStore: CacheStore?
  @State private var reach: ReachabilityMonitor
  @State private var drainer: MutationDrainer?

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
    _toastCenter = State(initialValue: ToastCenter())

    // ─────────────────────────────────────────────────────────────────────
    // Offline-queue plumbing (Welle D / Task 12)
    //
    // Build everything in a fixed order so each consumer gets the same
    // instance:
    //   1. cache   — single SwiftData container for the process
    //   2. reach   — single NWPathMonitor wrapper
    //   3. *Remote — raw Supabase / Mock repositories
    //   4. drainer — wires the queue → leadRemote (BYPASSES the decorator
    //                on purpose — the drainer IS what flushes the queue,
    //                routing it back through Cached* would loop)
    //   5. *Repo   — what the stores see; in mock-mode this is the bare
    //                Mock repo (spec §10.3: mock-mode bypasses cache so
    //                UI iteration sees deterministic seed data without
    //                a stale on-disk container masking changes)
    // ─────────────────────────────────────────────────────────────────────

    let cache = try? CacheStore()
    let reach = ReachabilityMonitor()

    let cardRemote: CardRepository = mockMode
      ? MockCardRepository()
      : SupabaseCardRepository()
    let leadRemote: LeadRepository = mockMode
      ? MockLeadRepository()
      : SupabaseLeadRepository()
    let analyticsRemote: AnalyticsRepository = mockMode
      ? MockAnalyticsRepository()
      : SupabaseAnalyticsRepository()

    // Resolve the store-facing repos. Mock-mode bypasses the cache entirely
    // (spec §10.3); live-mode wraps in Cached* IFF the cache came up. The
    // last `else` covers the cache-init-failed degraded path.
    let cardRepo: CardRepository
    let leadRepo: LeadRepository
    let analyticsRepo: AnalyticsRepository
    if mockMode {
      cardRepo      = cardRemote
      leadRepo      = leadRemote
      analyticsRepo = analyticsRemote
    } else if let cache {
      cardRepo      = CachedCardRepository(remote: cardRemote, cache: cache, reach: reach)
      analyticsRepo = CachedAnalyticsRepository(remote: analyticsRemote, cache: cache, reach: reach)
      // CachedLeadRepository needs the drainer to kick a flush after each
      // optimistic write. We build the drainer below; defer to a forward
      // declaration so we can capture it by reference.
      let preDrainer = MutationDrainer(cache: cache, remote: leadRemote)
      leadRepo = CachedLeadRepository(
        remote: leadRemote, cache: cache,
        drainer: preDrainer, reach: reach
      )
      _drainer = State(initialValue: preDrainer)
    } else {
      // Cache failed to init — fall back to bare remotes, no queue.
      cardRepo      = cardRemote
      leadRepo      = leadRemote
      analyticsRepo = analyticsRemote
    }

    _cacheStore = State(initialValue: cache)
    _reach      = State(initialValue: reach)

    _cardStore      = State(initialValue: CardStore(repository: cardRepo))
    _leadStore      = State(initialValue: LeadStore(repository: leadRepo))
    _analyticsStore = State(initialValue: AnalyticsStore(repository: analyticsRepo))
  }

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(auth)
        .environment(cardStore)
        .environment(leadStore)
        .environment(analyticsStore)
        .environment(toastCenter)
        .environment(reach)
        .environment(cacheStore)
        .environment(drainer)
        .toastBanner(from: toastCenter)
        .task {
          // Spin up reachability once per app session. NWPathMonitor delivers
          // the current path immediately on `start()`, so `reach.isConnected`
          // becomes accurate without any further nudging.
          reach.start()
        }
        .onChange(of: reach.isConnected) { _, isOnline in
          // Rising-edge: we just came back online → flush the mutation queue.
          if isOnline { Task { await drainer?.drain() } }
        }
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
              await drainer?.drain()      // and flush any queued mutations
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
