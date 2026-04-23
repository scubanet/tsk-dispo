import SwiftUI
import SwiftData

// ═══════════════════════════════════════
// MARK: - Send Signature Link View
// ═══════════════════════════════════════
//
// Owner-side sheet. Generates a token, writes a PendingSignature record to the
// public CloudKit DB, then exposes a share sheet with `divelogpro://` link.
//
struct SendSignatureLinkView: View {
    let dive: Dive

    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [DiverProfile]

    @State private var token: String = ""
    @State private var isCreating = true
    @State private var errorMessage: String?
    @State private var showingShareSheet = false
    @State private var copied = false

    private var profile: DiverProfile? { profiles.first }

    private var signingURL: URL? {
        token.isEmpty ? nil : RemoteSignatureService.signingURL(for: token)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.deepOcean.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DSSpacing.xl) {
                        diveHeader

                        if isCreating {
                            loadingBlock
                        } else if let err = errorMessage {
                            errorBlock(err)
                        } else if let url = signingURL {
                            readyBlock(url: url)
                        }
                    }
                    .padding(DSSpacing.xl)
                }
            }
            .navigationTitle(L10n.sendLinkTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.currentLanguage == "de" ? "Fertig" : "Done") {
                        dismiss()
                    }
                    .foregroundColor(.seafoam)
                    .fontWeight(.semibold)
                }
            }
            .toolbarBackground(Color.deepOcean, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .task { await createPendingIfNeeded() }
        .sheet(isPresented: $showingShareSheet) {
            if let url = signingURL {
                ShareSheet(items: [url])
            }
        }
    }

    // ═══════════════════════════════════════

    private var diveHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("#\(dive.number) · \(dive.formattedDate)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.seafoam)
            Text(dive.siteName)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
            Text(dive.siteLocation)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DSSpacing.l)
        .background(RoundedRectangle(cornerRadius: DSRadius.l).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: DSRadius.l).stroke(Color.cardBorder, lineWidth: 1))
    }

    private var loadingBlock: some View {
        VStack(spacing: DSSpacing.m) {
            ProgressView().tint(.seafoam)
            Text(L10n.generatingLink)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(DSSpacing.xxl)
        .background(RoundedRectangle(cornerRadius: DSRadius.l).fill(Color.white.opacity(0.04)))
    }

    private func errorBlock(_ msg: String) -> some View {
        VStack(spacing: DSSpacing.m) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundColor(.coral)
            Text(msg)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            Button {
                errorMessage = nil
                Task { await createPendingIfNeeded(forceRegenerate: true) }
            } label: {
                Text(L10n.currentLanguage == "de" ? "Nochmal versuchen" : "Try again")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.seafoam)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(DSSpacing.xxl)
        .background(RoundedRectangle(cornerRadius: DSRadius.l).fill(Color.white.opacity(0.04)))
    }

    private func readyBlock(url: URL) -> some View {
        VStack(spacing: DSSpacing.l) {
            // Icon
            Image(systemName: "link.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.seafoam)

            Text(L10n.linkReady)
                .font(.headline)
                .foregroundColor(.white)

            Text(L10n.linkShareHint)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)

            // Link preview
            Text(url.absoluteString)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.seafoam.opacity(0.9))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(DSSpacing.m)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: DSRadius.m).fill(Color.deepOcean.opacity(0.6)))
                .overlay(RoundedRectangle(cornerRadius: DSRadius.m).stroke(Color.seafoam.opacity(0.3), lineWidth: 1))

            // Actions
            VStack(spacing: DSSpacing.s) {
                Button {
                    showingShareSheet = true
                } label: {
                    Label(L10n.shareLink, systemImage: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.deepOcean)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.seafoam)
                        .clipShape(RoundedRectangle(cornerRadius: DSRadius.m))
                }

                Button {
                    UIPasteboard.general.string = url.absoluteString
                    copied = true
                    Task {
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        copied = false
                    }
                } label: {
                    Label(copied
                          ? (L10n.currentLanguage == "de" ? "Kopiert!" : "Copied!")
                          : L10n.copyLink,
                          systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: DSRadius.m).stroke(Color.white.opacity(0.2), lineWidth: 1))
                }
            }

            // Waiting state footer
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 11))
                    Text(L10n.waitingForSignature)
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white.opacity(0.6))

                Text(expiryHint)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.top, DSSpacing.s)
        }
        .frame(maxWidth: .infinity)
        .padding(DSSpacing.xxl)
        .background(RoundedRectangle(cornerRadius: DSRadius.l).fill(Color.white.opacity(0.04)))
    }

    private var expiryHint: String {
        let days = RemoteSignatureService.expiryDays
        return L10n.currentLanguage == "de"
            ? "Link ist \(days) Tage gültig"
            : "Link valid for \(days) days"
    }

    // ═══════════════════════════════════════

    private func createPendingIfNeeded(forceRegenerate: Bool = false) async {
        if !forceRegenerate && !token.isEmpty { return }

        let newToken = UUID().uuidString
        let expires  = Calendar.current.date(
            byAdding: .day, value: RemoteSignatureService.expiryDays, to: .now
        ) ?? .now.addingTimeInterval(7 * 24 * 3600)

        let payload = RemoteSignatureService.PendingPayload(
            token: newToken,
            diveNumber: dive.number,
            siteName: dive.siteName,
            siteLocation: dive.siteLocation,
            diveDate: dive.date,
            maxDepth: dive.maxDepth,
            totalTime: dive.totalTime,
            ownerName: profile?.name.isEmpty == false ? profile!.name : "Diver",
            expiresAt: expires
        )

        do {
            try await RemoteSignatureService.createPending(payload)
            // Record the pending token on the Dive so we can poll for it later
            // even after the sheet closes. Stored as a placeholder DiveSignature
            // with method "link" and isVerified=false — upgraded when completed.
            await MainActor.run {
                token = newToken
                isCreating = false
                recordPendingPlaceholder(token: newToken)
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isCreating = false
            }
        }
    }

    private func recordPendingPlaceholder(token: String) {
        // Create a "pending" DiveSignature so polling later knows which tokens
        // belong to this dive. We keep these hidden from the signature list
        // UI by filtering on `isVerified == false && method == "link"` in the
        // pending state, and flip to verified when the buddy finishes signing.
        let alreadyHasPlaceholder = (dive.signatures ?? []).contains {
            $0.method == "link" && $0.linkToken == token
        }
        guard !alreadyHasPlaceholder else { return }

        let sig = DiveSignature(
            buddyName: "",
            buddyPadiNumber: "",
            method: "link",
            signedAt: .now,
            isVerified: false
        )
        sig.linkToken = token
        if dive.signatures == nil { dive.signatures = [] }
        dive.signatures?.append(sig)
    }
}

// ═══════════════════════════════════════
// MARK: - Share Sheet wrapper
// ═══════════════════════════════════════

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) { }
}
