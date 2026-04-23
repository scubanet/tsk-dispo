import SwiftUI
import SwiftData

@main
struct DiveLogProApp: App {
    // First-run flag persisted in UserDefaults (synced via iCloud Key-Value
    // store is NOT wired here — this is a per-device flag by design so the
    // onboarding appears on each device once).
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    // Post-launch splash (shown briefly over the main UI)
    @State private var showLaunch = true

    // Sign in with Apple — app-wide auth state. The service hydrates itself
    // from Keychain on init, so `isSignedIn` is accurate from the first tick.
    @State private var appleSignIn = AppleSignInService.shared

    // Deep-link state for `divelogpro://remote-sign?token=…`
    @State private var remoteSignToken: String?

    // Shared soft-delete store — holds a dive in "pending delete" state for
    // a few seconds so the user can tap Undo. LogbookTab renders the
    // snackbar; DiveDetailView schedules via the same instance so a
    // delete-from-detail lands in the logbook with the Undo banner showing.
    @State private var deleteUndoManager = DeleteUndoManager()

    // Scene phase observer — commits any pending delete when the app goes
    // to the background so work-in-progress doesn't vanish silently.
    @Environment(\.scenePhase) private var scenePhase

    // ═══════════════════════════════════════
    // MARK: - ModelContainer (SwiftData + CloudKit)
    // ═══════════════════════════════════════
    //
    // Sync is enabled via `cloudKitDatabase: .automatic`. SwiftData will mirror
    // all @Model types to the user's private CloudKit database. Requirements:
    //
    //   1. CloudKit capability enabled in Xcode → Signing & Capabilities.
    //   2. iCloud container identifier (e.g. iCloud.com.weckherlin.DiveLogPro).
    //   3. Push Notifications + Background Modes (Remote notifications) — used
    //      for silent sync pushes.
    //
    // See ICLOUD_SETUP.md at the project root for the full checklist.
    //
    // Schema constraints we already satisfy:
    //   • Every property has a default value or is optional.
    //   • No @Attribute(.unique) constraints.
    //   • All relationships have an inverse; to-many relationships initialise
    //     to [] in the @Model init.
    //
    let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Dive.self,
            DiverProfile.self,
            DiveSite.self,
            Buddy.self,
            DiveSignature.self
        ])

        // Try CloudKit-backed first; fall back to a local-only container if
        // CloudKit is unavailable (simulator without signed-in iCloud, unit
        // tests, misconfigured entitlements, etc.). Without the fallback a
        // user with a broken iCloud setup would see an empty app instead of a
        // working offline logbook.
        let cloudConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(for: schema, configurations: [cloudConfig])
        } catch {
            #if DEBUG
            print("[DiveLogPro] CloudKit ModelContainer failed: \(error)")
            print("[DiveLogPro] Falling back to local-only store.")
            #endif
            let localConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
            do {
                return try ModelContainer(for: schema, configurations: [localConfig])
            } catch {
                fatalError("Could not create local ModelContainer: \(error)")
            }
        }
    }()

    // ═══════════════════════════════════════

    var body: some Scene {
        WindowGroup {
            ZStack {
                // ── Root decision ─────────────────────
                // 1) not signed in with Apple → SignInView (gateway)
                // 2) signed in but onboarding incomplete → OnboardingView over
                //    the tab view (so SwiftData warms up behind it)
                // 3) signed in + onboarded → MainTabView
                //
                if appleSignIn.isSignedIn {
                    MainTabView()
                        .fullScreenCover(isPresented: Binding(
                            get: { !hasCompletedOnboarding },
                            set: { newValue in
                                if !newValue { hasCompletedOnboarding = true }
                            }
                        )) {
                            OnboardingView()
                                .interactiveDismissDisabled()
                        }
                } else {
                    SignInView()
                        .transition(.opacity)
                }

                // Brand splash overlay — fades out after a short delay.
                if showLaunch {
                    LaunchScreenView()
                        .transition(.opacity)
                        .zIndex(10)
                        .task {
                            try? await Task.sleep(for: .milliseconds(900))
                            withAnimation(.easeOut(duration: 0.35)) {
                                showLaunch = false
                            }
                        }
                }
            }
            // Re-check Apple credential state on every launch. If the user
            // revoked access via Settings we wipe our Keychain and push them
            // back to SignInView automatically.
            .task {
                await appleSignIn.refreshCredentialState()
            }
            // Handle `divelogpro://remote-sign?token=…` links (Feature 3).
            .onOpenURL { url in
                if let token = RemoteSignatureService.token(fromURL: url) {
                    remoteSignToken = token
                }
            }
            .sheet(item: Binding(
                get: { remoteSignToken.map { RemoteSignToken(id: $0) } },
                set: { remoteSignToken = $0?.id }
            )) { wrapper in
                RemoteSignatureLandingView(token: wrapper.id)
            }
            .animation(.easeInOut(duration: 0.25), value: appleSignIn.isSignedIn)
            .environment(deleteUndoManager)
            .onChange(of: scenePhase) { _, newPhase in
                // Don't let a pending delete hang around across app
                // suspension — commit it now so the user's intent is honored
                // and CloudKit gets the tombstone before the app freezes.
                if newPhase == .background || newPhase == .inactive {
                    deleteUndoManager.commitImmediate(in: sharedModelContainer.mainContext)
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }
}

// Small Identifiable wrapper so we can drive a `.sheet(item:)` off the
// optional token without writing the same boilerplate inline.
private struct RemoteSignToken: Identifiable, Hashable {
    let id: String
}
