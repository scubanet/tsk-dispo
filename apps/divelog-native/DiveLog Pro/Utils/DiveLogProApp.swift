import SwiftUI
import SwiftData
import AtollCore
import os

private let logger = Logger(subsystem: "com.weckherlin.DiveLogPro", category: "CloudKit")

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

    // Deep-link state for dive-computer file opens (.uddf/.fit)
    @State private var pendingImportURL: URL?

    // Shared soft-delete store — holds a dive in "pending delete" state for
    // a few seconds so the user can tap Undo. LogbookTab renders the
    // snackbar; DiveDetailView schedules via the same instance so a
    // delete-from-detail lands in the logbook with the Undo banner showing.
    @State private var deleteUndoManager = DeleteUndoManager()

    // Scene phase observer — commits any pending delete when the app goes
    // to the background so work-in-progress doesn't vanish silently.
    @Environment(\.scenePhase) private var scenePhase

    // CloudKit convergence renumber — fires a debounced renumber after each
    // successful CloudKit import so that dives inserted on another device
    // converge to the same sequential numbering on this device.
    @State private var renumberCoordinator: CloudKitRenumberCoordinator?

    // Atoll Hub bridge — writes our profile/activity snapshot into the
    // shared App Group container so Atoll Hub can read it offline.
    private let atollBridge = DiveLogBridge()

    // Atoll-Backend (Phase 2): Supabase-Config muss vor dem ersten Zugriff
    // auf SupabaseClient.shared registriert sein.
    init() {
        AtollCoreConfig.register(DiveLogSupabaseConfig())
    }

    // ═══════════════════════════════════════
    // MARK: - ModelContainer (SwiftData + CloudKit)
    // ═══════════════════════════════════════

    static let isCloudKitAvailable: Bool = _isCloudKitAvailable
    static let cloudKitError: String? = _cloudKitError

    private static let (_container, _isCloudKitAvailable, _cloudKitError): (ModelContainer, Bool, String?) = {
        let schema = Schema([
            Dive.self,
            DivePhoto.self,
            DiverProfile.self,
            DiveSite.self,
            Buddy.self,
            DiveSignature.self,
            Student.self,
            PoolSession.self,
            SkillCompletion.self
        ])

        let cloudConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [cloudConfig])
            logger.info("CloudKit ModelContainer created successfully")
            return (container, true, nil)
        } catch {
            let msg = "\(error)"
            logger.error("CloudKit ModelContainer failed: \(msg)")
            logger.error("Falling back to local-only store — data will NOT sync!")

            let localConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
            do {
                let container = try ModelContainer(for: schema, configurations: [localConfig])
                return (container, false, msg)
            } catch {
                fatalError("Could not create local ModelContainer: \(error)")
            }
        }
    }()

    let sharedModelContainer: ModelContainer = _container

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
                #if DEBUG
                DiveLogBridge.runRoundTripSelfCheck()
                #endif
                await appleSignIn.refreshCredentialState()
                await AtollSessionService.shared.bootstrap()
                await SupabaseLogbookPublisher(container: sharedModelContainer).publishAll()
                migratePhotosToCloudKit()
                if renumberCoordinator == nil {
                    renumberCoordinator = CloudKitRenumberCoordinator(container: sharedModelContainer)
                }
                await DiveLogBridgePublisher(
                    container: sharedModelContainer,
                    bridge: atollBridge
                ).publish()
            }
            // Handle `divelogpro://remote-sign?token=…` links (Feature 3).
            .onOpenURL { url in
                // Branch on URL type:
                //  - divelogpro://remote-sign?token=… → remote signature flow
                //  - file with .uddf or .fit extension → dive-computer import flow
                if let token = RemoteSignatureService.token(fromURL: url) {
                    remoteSignToken = token
                } else if url.isFileURL {
                    let ext = url.pathExtension.lowercased()
                    if ext == "uddf" || ext == "fit" {
                        pendingImportURL = url
                    }
                }
            }
            .sheet(item: Binding(
                get: { remoteSignToken.map { RemoteSignToken(id: $0) } },
                set: { remoteSignToken = $0?.id }
            )) { wrapper in
                RemoteSignatureLandingView(token: wrapper.id)
            }
            .sheet(item: Binding(
                get: { pendingImportURL.map { IdentifiableURL(url: $0) } },
                set: { pendingImportURL = $0?.url }
            )) { wrapper in
                DiveComputerImportSheet(fileURL: wrapper.url) { _, _ in
                    pendingImportURL = nil
                }
            }
            .animation(.easeInOut(duration: 0.25), value: appleSignIn.isSignedIn)
            .overlay(alignment: .top) {
                if !Self.isCloudKitAvailable {
                    cloudKitWarningBanner
                }
            }
            .environment(deleteUndoManager)
            .environment(\.atollBridge, atollBridge)
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

    /// Backfills `DivePhoto` records for any legacy dives that only carry
    /// filenames in `photoFilenames`. Runs detached on a background priority
    /// so a large logbook doesn't stall the launch screen. Hops to MainActor
    /// for the actual SwiftData work because `ModelContext` is main-thread-bound.
    /// Idempotent — `migrateLocalPhotosToCloudKit` skips files that already
    /// have a record, so it's safe to invoke on every launch.
    private func migratePhotosToCloudKit() {
        let container = sharedModelContainer
        Task.detached(priority: .background) { @MainActor in
            let ctx = container.mainContext
            let dives = (try? ctx.fetch(FetchDescriptor<Dive>())) ?? []
            var migrated = 0
            for dive in dives where !dive.photoFilenames.isEmpty {
                let before = dive.photos?.count ?? 0
                PhotoStore.migrateLocalPhotosToCloudKit(dive: dive, context: ctx)
                migrated += (dive.photos?.count ?? 0) - before
            }
            if migrated > 0 {
                try? ctx.save()
                print("PhotoStore: migrated \(migrated) legacy photo(s) to DivePhoto records")
            }
        }
    }

    private var cloudKitWarningBanner: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.icloud.fill")
                    .font(.system(size: 14))
                Text(L10n.currentLanguage == "de"
                     ? "iCloud-Sync fehlgeschlagen — lokaler Modus"
                     : "iCloud sync failed — local mode")
                    .font(.system(size: 12, weight: .semibold))
            }
            if let err = Self.cloudKitError {
                Text(err)
                    .font(.system(size: 10))
                    .lineLimit(2)
                    .opacity(0.8)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.red.opacity(0.9))
        .padding(.top, 50)
    }
}

// Small Identifiable wrapper so we can drive a `.sheet(item:)` off the
// optional token without writing the same boilerplate inline.
private struct RemoteSignToken: Identifiable, Hashable {
    let id: String
}

/// Identifiable wrapper so `.sheet(item:)` can present a URL.
private struct IdentifiableURL: Identifiable {
    let url: URL
    var id: URL { url }
}

private struct DiveLogBridgeKey: EnvironmentKey {
    static let defaultValue: DiveLogBridge? = nil
}

extension EnvironmentValues {
    var atollBridge: DiveLogBridge? {
        get { self[DiveLogBridgeKey.self] }
        set { self[DiveLogBridgeKey.self] = newValue }
    }
}
