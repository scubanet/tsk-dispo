import SwiftUI

// ═══════════════════════════════════════
// MARK: - Remote Signature Landing View
// ═══════════════════════════════════════
//
// Buddy-side. Opens when a `divelogpro://remote-sign?token=…` link is tapped.
// Loads the matching PendingSignature from the public CloudKit DB, shows a
// read-only dive summary, and lets the buddy sign. The signature is stored as
// a CompletedSignature record which the owner polls for.
//
struct RemoteSignatureLandingView: View {
    let token: String

    @Environment(\.dismiss) private var dismiss

    @State private var loadState: LoadState = .loading
    @State private var pending: RemoteSignatureService.PendingPayload?

    @State private var buddyName = ""
    @State private var buddyPadi = ""
    @State private var strokes: [[CGPoint]] = []
    @State private var canvasSize: CGSize = .zero

    @State private var isSaving = false
    @State private var didSubmit = false
    @State private var saveError: String?

    enum LoadState {
        case loading
        case ready
        case expired
        case notFound
        case error(String)
    }

    private var canSave: Bool {
        !buddyName.trimmingCharacters(in: .whitespaces).isEmpty && !strokes.isEmpty && !isSaving
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.deepOcean.ignoresSafeArea()

                switch loadState {
                case .loading:
                    loadingView
                case .expired:
                    messageView(icon: "hourglass", title: L10n.remoteSignExpired,
                                tint: .coral)
                case .notFound:
                    messageView(icon: "questionmark.circle",
                                title: L10n.remoteSignNotFound,
                                tint: .coral)
                case .error(let msg):
                    messageView(icon: "exclamationmark.triangle.fill",
                                title: msg, tint: .coral)
                case .ready:
                    if didSubmit {
                        thanksView
                    } else {
                        signForm
                    }
                }
            }
            .navigationTitle(L10n.remoteSignTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.currentLanguage == "de" ? "Abbrechen" : "Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white.opacity(0.7))
                }
                if case .ready = loadState, !didSubmit {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { Task { await submit() } } label: {
                            if isSaving {
                                ProgressView().tint(.seafoam)
                            } else {
                                Text(L10n.currentLanguage == "de" ? "Senden" : "Send")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(canSave ? .seafoam : .white.opacity(0.25))
                            }
                        }
                        .disabled(!canSave)
                    }
                }
            }
            .toolbarBackground(Color.deepOcean, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .task { await load() }
    }

    // ═══════════════════════════════════════
    // MARK: Subviews
    // ═══════════════════════════════════════

    private var loadingView: some View {
        VStack(spacing: DSSpacing.m) {
            ProgressView().tint(.seafoam)
            Text(L10n.remoteSignLoading)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
    }

    private func messageView(icon: String, title: String, tint: Color) -> some View {
        VStack(spacing: DSSpacing.l) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(tint)
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Button {
                dismiss()
            } label: {
                Text(L10n.currentLanguage == "de" ? "Schließen" : "Close")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.seafoam)
            }
        }
        .padding(DSSpacing.xxl)
    }

    private var thanksView: some View {
        VStack(spacing: DSSpacing.l) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.seafoam)
            Text(L10n.remoteSignThanks)
                .font(.title3.weight(.bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            if let name = pending?.ownerName, !name.isEmpty {
                Text(L10n.currentLanguage == "de"
                     ? "\(name) bekommt deine Unterschrift automatisch."
                     : "\(name) will receive your signature automatically.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            Button {
                dismiss()
            } label: {
                Text(L10n.currentLanguage == "de" ? "Fertig" : "Done")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.deepOcean)
                    .frame(maxWidth: 200)
                    .padding(.vertical, 14)
                    .background(Color.seafoam)
                    .clipShape(RoundedRectangle(cornerRadius: DSRadius.m))
            }
            .padding(.top, DSSpacing.m)
        }
        .padding(DSSpacing.xxl)
    }

    private var signForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.l) {
                if let p = pending {
                    diveCard(p)
                }

                VStack(alignment: .leading, spacing: 12) {
                    FormField(
                        label: L10n.currentLanguage == "de" ? "Dein Name" : "Your Name",
                        text: $buddyName,
                        placeholder: L10n.currentLanguage == "de" ? "Vor- und Nachname" : "Full name"
                    )
                    FormField(
                        label: L10n.currentLanguage == "de" ? "PADI-Nummer (optional)" : "PADI Number (optional)",
                        text: $buddyPadi,
                        placeholder: "e.g. 335680"
                    )
                }

                // Canvas
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text((L10n.currentLanguage == "de" ? "Deine Unterschrift" : "Your Signature").uppercased())
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.labelDim)
                            .tracking(1.2)
                        Spacer()
                        if !strokes.isEmpty {
                            Button {
                                withAnimation(.easeOut(duration: 0.15)) { strokes = [] }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text(L10n.currentLanguage == "de" ? "Löschen" : "Clear")
                                }
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.coral.opacity(0.9))
                            }
                        }
                    }

                    ZStack(alignment: .bottomLeading) {
                        SignatureCanvas(strokes: $strokes)
                            .frame(height: 220)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.oceanBlue.opacity(0.3), lineWidth: 1)
                            )
                            .background(
                                GeometryReader { geo in
                                    Color.clear
                                        .onAppear { canvasSize = geo.size }
                                        .onChange(of: geo.size) { _, newSize in canvasSize = newSize }
                                }
                            )

                        if strokes.isEmpty {
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Text(L10n.currentLanguage == "de" ? "Hier unterschreiben" : "Sign here")
                                        .font(.system(size: 13))
                                        .foregroundColor(.deepOcean.opacity(0.25))
                                    Spacer()
                                }
                                .padding(.bottom, 24)
                            }
                            .allowsHitTesting(false)
                        }

                        Rectangle()
                            .fill(Color.deepOcean.opacity(0.15))
                            .frame(height: 1)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 40)
                            .allowsHitTesting(false)
                    }
                }

                if let err = saveError {
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundColor(.coral)
                        .padding(.top, 4)
                }
            }
            .padding(DSSpacing.xl)
        }
    }

    private func diveCard(_ p: RemoteSignatureService.PendingPayload) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("#\(p.diveNumber)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.seafoam)
                Text(p.diveDate.formatted(.dateTime.day().month(.abbreviated).year()))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
            Text(p.siteName)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
            Text(p.siteLocation)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.5))

            HStack(spacing: 14) {
                stat(icon: "arrow.down", text: "\(String(format: "%.0f", p.maxDepth)) m")
                stat(icon: "clock", text: "\(p.totalTime) min")
            }
            .padding(.top, 4)

            if !p.ownerName.isEmpty {
                Divider().background(Color.white.opacity(0.1)).padding(.vertical, 6)
                Text(L10n.currentLanguage == "de"
                     ? "Signieranfrage von \(p.ownerName)"
                     : "Signature request from \(p.ownerName)")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.55))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DSSpacing.l)
        .background(RoundedRectangle(cornerRadius: DSRadius.l).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: DSRadius.l).stroke(Color.cardBorder, lineWidth: 1))
    }

    private func stat(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10)).foregroundColor(.white.opacity(0.4))
            Text(text).font(.system(size: 12, weight: .semibold)).foregroundColor(.white.opacity(0.7))
        }
    }

    // ═══════════════════════════════════════
    // MARK: Load / Submit
    // ═══════════════════════════════════════

    private func load() async {
        do {
            let p = try await RemoteSignatureService.fetchPending(token: token)
            await MainActor.run {
                pending = p
                loadState = .ready
            }
        } catch let err as RemoteSignatureService.ServiceError {
            await MainActor.run {
                switch err {
                case .expired:  loadState = .expired
                case .notFound: loadState = .notFound
                case .cloudKit(let e): loadState = .error(e.localizedDescription)
                }
            }
        } catch {
            await MainActor.run { loadState = .error(error.localizedDescription) }
        }
    }

    private func submit() async {
        guard canSave else { return }
        await MainActor.run { isSaving = true; saveError = nil }

        let renderSize = canvasSize.width > 0 && canvasSize.height > 0
            ? canvasSize
            : CGSize(width: 600, height: 220)
        guard let png = SignatureRenderer.pngData(strokes: strokes, size: renderSize) else { return }

        let payload = RemoteSignatureService.CompletedPayload(
            token: token,
            buddyName: buddyName.trimmingCharacters(in: .whitespaces),
            buddyPadi: buddyPadi.trimmingCharacters(in: .whitespaces),
            signaturePNGData: png,
            signedAt: .now
        )

        do {
            try await RemoteSignatureService.saveCompleted(payload)
            await MainActor.run {
                didSubmit = true
                isSaving = false
            }
        } catch {
            await MainActor.run {
                saveError = error.localizedDescription
                isSaving = false
            }
        }
    }
}
