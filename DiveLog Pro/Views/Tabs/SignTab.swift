import SwiftUI
import SwiftData

struct SignTab: View {
    @Query(sort: \Dive.date, order: .reverse) private var dives: [Dive]

    @Environment(\.modelContext) private var ctx

    @State private var signingDive: Dive?
    @State private var showingScanner = false
    @State private var scannedIdentity: QRCodeService.Identity?
    @State private var showingInvalidQR = false
    @State private var showingMyQR = false
    @State private var linkDive: Dive?
    @State private var isPolling = false
    @State private var importToastCount = 0

    var body: some View {
        NavigationStack {
            ZStack {
                HeroBackground()

                ScrollView {
                    VStack(spacing: DSSpacing.l) {
                        myStampCard

                        HStack {
                            Text(L10n.currentLanguage == "de" ? "Deine Tauchgänge" : "Your Dives")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                        .padding(.top, DSSpacing.s)

                        if dives.isEmpty {
                            emptyState
                        } else {
                            VStack(spacing: DSSpacing.s + 2) {
                                ForEach(dives.prefix(20)) { dive in
                                    Button {
                                        signingDive = dive
                                    } label: {
                                        signatureRow(dive: dive)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, DSSpacing.xl)
                    .padding(.top, DSSpacing.s)
                    .padding(.bottom, DSSpacing.xxxl)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(L10n.tabSign)
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $signingDive) { dive in
                SignatureCaptureView(
                    dive: dive,
                    prefilledName: scannedIdentity?.name,
                    prefilledPadi: scannedIdentity?.padiNumber,
                    prefilledQRHash: scannedIdentity?.fingerprint
                )
                .onDisappear { scannedIdentity = nil }
            }
            .sheet(isPresented: $showingScanner) {
                QRScannerView { raw in
                    // Scanner sheet is about to dismiss. Defer the next sheet
                    // presentation by one runloop tick so the dismiss animation
                    // doesn't swallow it.
                    if let id = QRCodeService.parseIdentity(from: raw) {
                        scannedIdentity = id
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 400_000_000)
                            triggerSignWithPrefill()
                        }
                    } else {
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 400_000_000)
                            showingInvalidQR = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showingMyQR) {
                MyQRCodeView()
            }
            .sheet(item: $linkDive) { dive in
                SendSignatureLinkView(dive: dive)
            }
            .refreshable { await importCompletedSignatures() }
            .task { await importCompletedSignatures() }
            .alert(L10n.invalidQR, isPresented: $showingInvalidQR) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(L10n.currentLanguage == "de"
                     ? "Der gescannte Code ist kein gültiger DiveLog-Pro-Identity-Code."
                     : "The scanned code is not a valid DiveLog Pro identity code.")
            }
        }
    }

    // ═══════════════════════════════════════

    private var emptyState: some View {
        VStack(spacing: DSSpacing.m) {
            Image(systemName: "signature")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.tertiary)
            Text(L10n.currentLanguage == "de" ? "Noch keine TGs zum Signieren" : "No dives to sign yet")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // ═══════════════════════════════════════

    private var myStampCard: some View {
        VStack(spacing: DSSpacing.l) {
            Button { showingMyQR = true } label: {
                RoundedRectangle(cornerRadius: DSRadius.l, style: .continuous)
                    .fill(Color.white)
                    .frame(width: 160, height: 160)
                    .overlay(
                        VStack(spacing: DSSpacing.s) {
                            Image(systemName: "qrcode")
                                .font(.system(size: 60))
                                .foregroundStyle(Color.deepOcean)
                            Text(L10n.currentLanguage == "de" ? "Dein QR-Code" : "Your QR Code")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.deepOcean.opacity(0.6))
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DSRadius.l, style: .continuous)
                            .strokeBorder(Color.hairline.opacity(0.4), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)

            Text(L10n.currentLanguage == "de"
                 ? "Tippe einen TG unten an, um deinen Buddy direkt unterschreiben zu lassen"
                 : "Tap a dive below to have your buddy sign in person")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: DSSpacing.m) {
                actionButton(
                    icon: "qrcode.viewfinder",
                    label: L10n.currentLanguage == "de" ? "Scannen" : "Scan",
                    isEnabled: !dives.isEmpty,
                    action: { showingScanner = true }
                )
                actionButton(
                    icon: "hand.draw.fill",
                    label: L10n.currentLanguage == "de" ? "Unterschrift" : "Sign",
                    isEnabled: true,
                    action: { triggerFirstSign() }
                )
                actionButton(
                    icon: "link",
                    label: L10n.currentLanguage == "de" ? "Link senden" : "Send Link",
                    isEnabled: !dives.isEmpty,
                    action: { if let first = dives.first { linkDive = first } }
                )
            }
        }
        .padding(DSSpacing.xxl)
        .glassCard(cornerRadius: DSRadius.xxl)
    }

    private func triggerFirstSign() {
        if let first = dives.first { signingDive = first }
    }

    /// Called after a successful QR scan. Opens the latest dive with prefill.
    private func triggerSignWithPrefill() {
        if let first = dives.first { signingDive = first }
    }

    // ═══════════════════════════════════════
    // MARK: - Remote-Link polling
    // ═══════════════════════════════════════
    //
    // Collects every pending link-signature placeholder across all dives,
    // queries the public CloudKit DB for completed records, and upgrades any
    // matching placeholder in place. Also clears finished records from
    // CloudKit so the public DB doesn't grow unbounded.
    //
    private func importCompletedSignatures() async {
        guard !isPolling else { return }
        await MainActor.run { isPolling = true }
        defer { Task { @MainActor in isPolling = false } }

        // Gather { token → (dive, signature) } for every un-signed link placeholder.
        var map: [String: (Dive, DiveSignature)] = [:]
        for dive in dives {
            for sig in (dive.signatures ?? []) where sig.method == "link"
                && !sig.isVerified
                && !sig.linkToken.isEmpty {
                map[sig.linkToken] = (dive, sig)
            }
        }
        guard !map.isEmpty else { return }

        do {
            let completed = try await RemoteSignatureService.fetchCompleted(
                tokens: Array(map.keys)
            )
            guard !completed.isEmpty else { return }

            await MainActor.run {
                for payload in completed {
                    guard let (_, placeholder) = map[payload.token] else { continue }
                    placeholder.buddyName       = payload.buddyName
                    placeholder.buddyPadiNumber = payload.buddyPadi
                    placeholder.signatureImageData = payload.signaturePNGData
                    placeholder.signedAt        = payload.signedAt
                    placeholder.isVerified      = true
                    importToastCount += 1
                }
                try? ctx.save()
            }

            // Fire-and-forget cleanup of the CloudKit records.
            for payload in completed {
                await RemoteSignatureService.cleanup(token: payload.token)
            }
        } catch {
            #if DEBUG
            print("[SignTab] importCompletedSignatures failed: \(error)")
            #endif
        }
    }

    private func actionButton(
        icon: String,
        label: String,
        isEnabled: Bool,
        action: (() -> Void)? = nil
    ) -> some View {
        Button { action?() } label: {
            VStack(spacing: DSSpacing.xs + 2) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(isEnabled ? Color.appAccent : Color.secondary)
                    .frame(width: 52, height: 52)
                    .background(
                        Circle().fill(
                            isEnabled ? Color.appAccent.opacity(0.12)
                                      : Color.surfaceCard
                        )
                    )
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isEnabled ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    // ═══════════════════════════════════════

    private func signatureRow(dive: Dive) -> some View {
        // Pending link placeholders (method == "link" && !isVerified) are
        // kept on the dive only so we can poll for them — they should not
        // count toward the "signed" tally until the buddy actually completes.
        let sigList = dive.signatures ?? []
        let verified = sigList.filter { $0.isVerified || $0.method != "link" }
        let pendingLinkCount = sigList.filter { $0.method == "link" && !$0.isVerified }.count
        let signCount = verified.count
        let hasSignature = signCount > 0

        return HStack(spacing: DSSpacing.m) {
            Circle()
                .fill(hasSignature ? Color.appSuccess : Color.hairline)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text("#\(dive.number) — \(dive.siteName)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(dive.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if hasSignature {
                Text("\(signCount)×")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.appSuccess)
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Color.appSuccess)
            } else if pendingLinkCount > 0 {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.appAccent)
                Text(L10n.currentLanguage == "de" ? "Link offen" : "Link pending")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.appAccent)
            } else {
                Text(L10n.currentLanguage == "de" ? "Signieren" : "Sign")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.appEmphasis)
                Image(systemName: "hand.draw.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.appEmphasis.opacity(0.8))
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(DSSpacing.m + 2)
        .solidCard(cornerRadius: DSRadius.m)
    }
}
