import SwiftUI
import SwiftData

struct ProfileTab: View {
    @Environment(\.modelContext) private var ctx
    @Query private var profiles: [DiverProfile]
    @Query(sort: \Dive.date, order: .reverse) private var dives: [Dive]
    @Query private var buddies: [Buddy]
    @Query private var sites: [DiveSite]

    @State private var showingEdit = false
    @State private var showingExport = false
    @State private var showingMyQR = false
    @State private var showingSignOutConfirm = false
    @State private var showingDeleteConfirm = false
    @State private var showingDedupeConfirm = false
    @State private var dedupeResultMessage: String?
    @State private var showingLoadSampleConfirm = false
    @State private var sampleLoadedMessage: String?
    @State private var appleSignIn = AppleSignInService.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("appLanguage") private var language = "en"

    /// Picks the best profile to surface in the UI. Pure read — never mutates
    /// state. Deduplication is hoisted to `.onChange(of: profiles.count)` on
    /// the body so it doesn't fire on every view re-render.
    private var profile: DiverProfile? {
        guard !profiles.isEmpty else { return nil }
        let uid = AppleSignInService.shared.currentUserID
        if let uid, let match = profiles.first(where: { $0.appleUserID == uid }) {
            return match
        }
        return profiles.first(where: { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }) ?? profiles.first
    }

    var body: some View {
        NavigationStack {
            ZStack {
                HeroBackground()

                ScrollView {
                    VStack(spacing: DSSpacing.l) {
                        ProfileCard(profile: profile, onEdit: { showingEdit = true })
                        ProfileStampCard(profile: profile, onEdit: { showingEdit = true })

                        QuickStatsCard(dives: dives)
                            .padding(.top, DSSpacing.xs)

                        // ─── Settings ─────────────────────
                        HStack {
                            Text((L10n.currentLanguage == "de" ? "Einstellungen" : "Settings").uppercased())
                                .font(.caption2.weight(.semibold))
                                .tracking(0.8)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }

                        SettingsSection(
                            profile: profile,
                            language: $language,
                            onShowQR: { showingMyQR = true },
                            onShowExport: { showingExport = true }
                        )

                        // ─── Datenverwaltung ──────────────
                        HStack {
                            Text((L10n.currentLanguage == "de" ? "Datenverwaltung" : "Data Management").uppercased())
                                .font(.caption2.weight(.semibold))
                                .tracking(0.8)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.top, DSSpacing.m)

                        dataManagementCard

                        // ─── Account ──────────────────────
                        HStack {
                            Text((L10n.currentLanguage == "de" ? "Account" : "Account").uppercased())
                                .font(.caption2.weight(.semibold))
                                .tracking(0.8)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.top, DSSpacing.m)

                        accountCard

                        // App info
                        VStack(spacing: 4) {
                            Text("AtollLog")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.tertiary)
                            Text("Version 1.0")
                                .font(.system(size: 11))
                                .foregroundStyle(.quaternary)
                        }
                        .padding(.top, DSSpacing.l)
                    }
                    .padding(.horizontal, DSSpacing.xl)
                    .padding(.top, DSSpacing.s)
                    .padding(.bottom, DSSpacing.xxxl)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(L10n.tabProfile)
            .navigationBarTitleDisplayMode(.large)
            // Run profile-dedupe once when CloudKit syncs in extra DiverProfile
            // rows from another device. Hoisted out of the `profile` computed
            // property so it doesn't fire on every render.
            .onChange(of: profiles.count, initial: true) { _, newCount in
                if newCount > 1 {
                    deduplicateProfiles()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingEdit = true
                    } label: {
                        Text(L10n.currentLanguage == "de" ? "Bearbeiten" : "Edit")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.appAccent)
                    }
                    .disabled(profile == nil)
                }
            }
            .sheet(isPresented: $showingEdit) {
                if let p = profile {
                    ProfileEditView(profile: p)
                }
            }
            .sheet(isPresented: $showingExport) {
                ExportSheet()
            }
            .sheet(isPresented: $showingMyQR) {
                MyQRCodeView()
            }
            .confirmationDialog(
                L10n.currentLanguage == "de" ? "Wirklich abmelden?" : "Sign out?",
                isPresented: $showingSignOutConfirm,
                titleVisibility: .visible
            ) {
                Button(
                    L10n.currentLanguage == "de" ? "Abmelden" : "Sign Out",
                    role: .destructive
                ) {
                    performSignOut()
                }
                Button(
                    L10n.currentLanguage == "de" ? "Abbrechen" : "Cancel",
                    role: .cancel
                ) { }
            } message: {
                Text(L10n.currentLanguage == "de"
                     ? "Deine Tauchgänge bleiben in iCloud. Du musst dich nur wieder mit Apple anmelden."
                     : "Your dives stay in iCloud. You just have to sign in with Apple again.")
            }
            .confirmationDialog(
                duplicateCount > 0
                    ? (L10n.currentLanguage == "de"
                       ? "\(duplicateCount) Duplikate gefunden. Bereinigen?"
                       : "\(duplicateCount) duplicates found. Clean up?")
                    : (L10n.currentLanguage == "de"
                       ? "Keine Duplikate gefunden"
                       : "No duplicates found"),
                isPresented: $showingDedupeConfirm,
                titleVisibility: .visible
            ) {
                if duplicateCount > 0 {
                    Button(
                        L10n.currentLanguage == "de" ? "Bereinigen" : "Clean up",
                        role: .destructive
                    ) {
                        performDedupe()
                    }
                }
                Button(
                    L10n.currentLanguage == "de" ? "Abbrechen" : "Cancel",
                    role: .cancel
                ) { }
            } message: {
                Text(duplicateCount > 0
                     ? (L10n.currentLanguage == "de"
                        ? "Es werden die ältesten Einträge behalten. Die jüngeren Duplikate werden unwiderruflich gelöscht."
                        : "The oldest entries are kept. The newer duplicates will be deleted permanently.")
                     : (L10n.currentLanguage == "de"
                        ? "Alle deine Tauchgänge sind einzigartig."
                        : "All your dives are unique."))
            }
            .alert(
                dedupeResultMessage ?? "",
                isPresented: Binding(
                    get: { dedupeResultMessage != nil },
                    set: { if !$0 { dedupeResultMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { dedupeResultMessage = nil }
            }
            .confirmationDialog(
                L10n.currentLanguage == "de" ? "Beispieldaten laden?" : "Load sample data?",
                isPresented: $showingLoadSampleConfirm,
                titleVisibility: .visible
            ) {
                Button(
                    L10n.currentLanguage == "de" ? "Laden" : "Load"
                ) {
                    loadSampleData()
                }
                Button(
                    L10n.currentLanguage == "de" ? "Abbrechen" : "Cancel",
                    role: .cancel
                ) { }
            } message: {
                Text(L10n.currentLanguage == "de"
                     ? "Erzeugt 4 realistische Demo-Tauchgänge (Malaysia + Philippinen). Diese werden via iCloud auch auf deine anderen Geräte synchronisiert. Du kannst sie jederzeit einzeln löschen."
                     : "Creates 4 realistic demo dives (Malaysia + Philippines). These will sync via iCloud to your other devices. You can delete them individually anytime.")
            }
            .alert(
                sampleLoadedMessage ?? "",
                isPresented: Binding(
                    get: { sampleLoadedMessage != nil },
                    set: { if !$0 { sampleLoadedMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { sampleLoadedMessage = nil }
            }
            .confirmationDialog(
                L10n.currentLanguage == "de" ? "Account wirklich löschen?" : "Really delete account?",
                isPresented: $showingDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button(
                    L10n.currentLanguage == "de" ? "Alles löschen" : "Delete Everything",
                    role: .destructive
                ) {
                    performAccountDelete()
                }
                Button(
                    L10n.currentLanguage == "de" ? "Abbrechen" : "Cancel",
                    role: .cancel
                ) { }
            } message: {
                Text(L10n.currentLanguage == "de"
                     ? "Alle Tauchgänge, Buddies, Tauchplätze und dein Profil werden von diesem Gerät und aus deinem iCloud entfernt. Das lässt sich nicht rückgängig machen."
                     : "All dives, buddies, sites and your profile will be removed from this device and your iCloud. This cannot be undone.")
            }
            .onAppear(perform: ensureProfileExists)
        }
    }

    // ═══════════════════════════════════════
    // MARK: - Data Management Card

    /// A "duplicate" here means: same dive number AND same day AND same site.
    /// That three-way key is tight enough that legit dives (you can log two
    /// dives on the same day, but they'll have different numbers) never match,
    /// but exact CloudKit-sync duplicates always do.
    private var duplicateGroups: [[Dive]] {
        let grouped = Dictionary(grouping: dives) { dive -> String in
            let day = Calendar.current.startOfDay(for: dive.date).timeIntervalSince1970
            return "\(dive.number)|\(Int(day))|\(dive.siteName.lowercased())"
        }
        return grouped.values
            .filter { $0.count > 1 }
            .map { $0 } // keep groups as arrays
    }

    /// Total number of records we'd delete when cleaning up — we always keep
    /// the oldest entry in each group, so it's "group size minus one" summed.
    private var duplicateCount: Int {
        duplicateGroups.reduce(0) { $0 + ($1.count - 1) }
    }

    private var dataManagementCard: some View {
        VStack(spacing: 1) {
            // Sample-Data loader — only visible when the logbook is empty.
            // Opt-in by design: auto-seeding in a CloudKit env would create
            // duplicates as soon as sync catches up on secondary devices.
            if dives.isEmpty {
                Button {
                    showingLoadSampleConfirm = true
                } label: {
                    settingsRow(
                        icon: "sparkles",
                        label: L10n.currentLanguage == "de" ? "Beispieldaten laden" : "Load Sample Data"
                    ) {
                        HStack(spacing: 6) {
                            Text(L10n.currentLanguage == "de" ? "4 TGs" : "4 dives")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.appAccent)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            // Always visible so users know the feature exists; shows badge if
            // duplicates present.
            Button {
                showingDedupeConfirm = true
            } label: {
                settingsRow(
                    icon: "rectangle.on.rectangle.slash",
                    label: L10n.currentLanguage == "de" ? "Duplikate bereinigen" : "Clean up duplicates"
                ) {
                    HStack(spacing: 6) {
                        if duplicateCount > 0 {
                            Text("\(duplicateCount)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.appEmphasis))
                        } else {
                            Text(L10n.currentLanguage == "de" ? "Keine" : "None")
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    /// Delete all but the oldest dive in each duplicate group. "Oldest" means
    /// the one with the smallest `persistentModelID` — since SwiftData assigns
    /// IDs monotonically, that's the first record inserted (local), and the
    /// duplicates are the ones that came in later via CloudKit. Keeping the
    /// local one preserves any signatures/buddies that may already be wired up.
    private func performDedupe() {
        let groups = duplicateGroups
        var deletedCount = 0

        for group in groups {
            // Sort by persistent ID hash for stable ordering, keep first.
            let sorted = group.sorted { a, b in
                String(describing: a.persistentModelID) < String(describing: b.persistentModelID)
            }
            guard let keeper = sorted.first else { continue }
            for dive in group where dive !== keeper {
                ctx.delete(dive)
                deletedCount += 1
            }
        }

        // Close gaps that the deletions left in the chronological numbering.
        if deletedCount > 0, let profile = profiles.first {
            ctx.renumberDives(from: profile)
        }

        do {
            try ctx.save()
            dedupeResultMessage = L10n.currentLanguage == "de"
                ? "\(deletedCount) Duplikate entfernt."
                : "\(deletedCount) duplicates removed."
        } catch {
            dedupeResultMessage = L10n.currentLanguage == "de"
                ? "Fehler beim Speichern: \(error.localizedDescription)"
                : "Save failed: \(error.localizedDescription)"
        }
    }

    // ═══════════════════════════════════════
    // MARK: - Sample Data Loader

    /// Inserts the hand-crafted demo dives from `SampleData.createSampleDives()`
    /// into the live model context. Only triggerable while `dives.isEmpty` —
    /// that's enforced by the button being hidden otherwise. We save once at
    /// the end so CloudKit gets a single batched push rather than four
    /// individual ones.
    private func loadSampleData() {
        let samples = SampleData.createSampleDives()
        for dive in samples {
            ctx.insert(dive)
        }
        // Sample dives are constructed with `number: 0` placeholders;
        // renumber assigns the real chronological values from
        // profile.startingDiveNumber.
        if let profile = profiles.first {
            ctx.renumberDives(from: profile)
        }
        do {
            try ctx.save()
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            sampleLoadedMessage = L10n.currentLanguage == "de"
                ? "\(samples.count) Beispiel-Tauchgänge geladen."
                : "\(samples.count) sample dives loaded."
        } catch {
            sampleLoadedMessage = L10n.currentLanguage == "de"
                ? "Fehler beim Speichern: \(error.localizedDescription)"
                : "Save failed: \(error.localizedDescription)"
        }
    }

    // ═══════════════════════════════════════
    // MARK: - Account Card

    /// Best-available email for the account row. Keychain first (populated
    /// at first sign-in on this device), then DiverProfile.email (synced via
    /// CloudKit from whatever device first captured it). Apple only hands us
    /// the email on the initial auth — so on a second device with the same
    /// Apple ID, Keychain is empty and this fallback kicks in.
    private var accountEmail: String? {
        if let keychainEmail = appleSignIn.currentEmail,
           !keychainEmail.trimmingCharacters(in: .whitespaces).isEmpty {
            return keychainEmail
        }
        if let profileEmail = profile?.email,
           !profileEmail.trimmingCharacters(in: .whitespaces).isEmpty {
            return profileEmail
        }
        return nil
    }

    /// Apple's private-relay addresses look like `xxx@privaterelay.appleid.com`.
    /// We surface these with a small "Privat-Relay" hint so the user isn't
    /// surprised by an unfamiliar-looking address.
    private var isPrivateRelayEmail: Bool {
        guard let email = accountEmail else { return false }
        return email.lowercased().hasSuffix("@privaterelay.appleid.com")
    }

    private var accountCard: some View {
        VStack(spacing: 1) {
            // Apple identity row — shows email as subtitle
            appleIdentityRow

            // Sign out
            Button {
                showingSignOutConfirm = true
            } label: {
                settingsRow(icon: "rectangle.portrait.and.arrow.right",
                            label: L10n.currentLanguage == "de" ? "Abmelden" : "Sign Out") {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            // Delete account (Apple Review mandatory)
            Button {
                showingDeleteConfirm = true
            } label: {
                settingsRow(icon: "trash.fill",
                            label: L10n.currentLanguage == "de" ? "Account löschen" : "Delete Account") {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .foregroundStyle(Color.appEmphasis)
            }
            .buttonStyle(.plain)
        }
    }

    /// Two-line identity row — primary "Angemeldet mit Apple" with the email
    /// as subtitle underneath. Custom-built because `settingsRow` expects a
    /// single-line label; this variant gives the account section the
    /// classic iOS identity-header feel.
    private var appleIdentityRow: some View {
        HStack(spacing: DSSpacing.m + 2) {
            Image(systemName: "apple.logo")
                .font(.system(size: 16))
                .foregroundStyle(Color.appAccent)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.currentLanguage == "de"
                     ? "Angemeldet mit Apple"
                     : "Signed in with Apple")
                    .font(.system(size: 15))
                    .foregroundStyle(.primary)

                if let email = accountEmail {
                    HStack(spacing: 6) {
                        Text(email)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        if isPrivateRelayEmail {
                            Text(L10n.currentLanguage == "de" ? "PRIVAT-RELAY" : "PRIVATE RELAY")
                                .font(.system(size: 8, weight: .bold))
                                .tracking(0.5)
                                .foregroundStyle(Color.appAccent)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(
                                    Capsule().fill(Color.appAccent.opacity(0.12))
                                )
                        }
                    }
                } else {
                    Text(L10n.currentLanguage == "de"
                         ? "E-Mail nicht geteilt"
                         : "Email not shared")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 13))
                .foregroundStyle(Color.appSuccess)
        }
        .padding(DSSpacing.m + 2)
        .solidCard(cornerRadius: DSRadius.m)
    }

    // ═══════════════════════════════════════
    // MARK: - Account actions

    /// Local sign-out. Keeps SwiftData / CloudKit content intact so the user
    /// sees their logbook again after re-signing in with the same Apple ID.
    private func performSignOut() {
        appleSignIn.signOutLocal()
        // Note: we intentionally do NOT reset hasCompletedOnboarding — if the
        // user signs back in with the same Apple ID they skip straight into
        // the app.
    }

    /// Full account delete — wipes SwiftData (and CloudKit via the container),
    /// keychain, onboarding flag, then drops back to SignInView.
    /// Apple itself doesn't support an app-initiated token revoke, but the
    /// local wipe + keychain clear is what Apple reviewers require.
    private func performAccountDelete() {
        // 1. Delete all SwiftData models. The @Model types cascade through
        //    their relationships on their own.
        for dive in dives { ctx.delete(dive) }
        for sig in profiles.flatMap({ _ in [] as [DiveSignature] }) { ctx.delete(sig) }
        for buddy in buddies { ctx.delete(buddy) }
        for site in sites { ctx.delete(site) }
        for p in profiles { ctx.delete(p) }
        try? ctx.save()

        // 2. Wipe keychain + in-memory SIWA state.
        appleSignIn.signOutLocal()

        // 3. Reset UI flags so onboarding runs again if the user returns.
        hasCompletedOnboarding = false
    }

    // ═══════════════════════════════════════
    // MARK: - Bootstrap

    private func ensureProfileExists() {
        guard profiles.isEmpty else { return }
        let p = DiverProfile(
            name: "",
            padiNumber: "",
            certLevel: "OWD",
            isInstructor: false,
            useMetric: true,
            language: language
        )
        ctx.insert(p)
    }

    private func deduplicateProfiles() {
        guard profiles.count > 1 else { return }
        let uid = AppleSignInService.shared.currentUserID

        // Score profiles by how much data they carry — always keep the richest one.
        func richness(_ p: DiverProfile) -> Int {
            var s = 0
            if !p.name.trimmingCharacters(in: .whitespaces).isEmpty { s += 10 }
            if !p.padiNumber.isEmpty { s += 5 }
            if !p.email.isEmpty { s += 3 }
            if p.profileImageData != nil { s += 5 }
            if p.stampImageData != nil { s += 5 }
            if p.appleUserID == uid { s += 20 }
            return s
        }

        let sorted = profiles.sorted { richness($0) > richness($1) }
        let primary = sorted[0]

        for p in sorted.dropFirst() {
            if primary.name.trimmingCharacters(in: .whitespaces).isEmpty,
               !p.name.trimmingCharacters(in: .whitespaces).isEmpty {
                primary.name = p.name
            }
            if primary.padiNumber.isEmpty, !p.padiNumber.isEmpty { primary.padiNumber = p.padiNumber }
            if primary.email.isEmpty, !p.email.isEmpty { primary.email = p.email }
            if primary.phone.isEmpty, !p.phone.isEmpty { primary.phone = p.phone }
            if primary.certLevel == "OWD", !p.certLevel.isEmpty, p.certLevel != "OWD" {
                primary.certLevel = p.certLevel
            }
            if primary.profileImageData == nil { primary.profileImageData = p.profileImageData }
            if primary.stampImageData == nil { primary.stampImageData = p.stampImageData }
            if primary.appleUserID == nil { primary.appleUserID = p.appleUserID }
            if primary.defaultDiveCenter.isEmpty, !p.defaultDiveCenter.isEmpty {
                primary.defaultDiveCenter = p.defaultDiveCenter
            }
            ctx.delete(p)
        }
        try? ctx.save()
    }

}
