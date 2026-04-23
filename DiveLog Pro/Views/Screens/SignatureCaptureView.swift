import SwiftUI
import SwiftData

// ═══════════════════════════════════════
// MARK: - Signature Capture View
// ═══════════════════════════════════════

/// Sheet that lets a buddy sign a specific dive. Captures name, PADI number,
/// and a finger-drawn signature which is rendered to PNG and stored on the
/// DiveSignature model.
struct SignatureCaptureView: View {
    let dive: Dive
    var prefilledName: String? = nil
    var prefilledPadi: String? = nil
    var prefilledQRHash: String? = nil    // when set → method = "qr"

    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    @State private var buddyName: String = ""
    @State private var buddyPadi: String = ""
    @State private var strokes: [[CGPoint]] = []
    @State private var canvasSize: CGSize = .zero
    @State private var showingMissingNameAlert = false
    @State private var didApplyPrefill = false

    private var canSave: Bool {
        !buddyName.trimmingCharacters(in: .whitespaces).isEmpty && !strokes.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.deepOcean.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        diveHeader

                        // Buddy info
                        VStack(alignment: .leading, spacing: 12) {
                            FormField(
                                label: L10n.currentLanguage == "de" ? "Name des Buddys" : "Buddy Name",
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
                                Text((L10n.currentLanguage == "de" ? "Unterschrift" : "Signature").uppercased())
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

                                // Signature baseline + hint
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

                                // baseline
                                Rectangle()
                                    .fill(Color.deepOcean.opacity(0.15))
                                    .frame(height: 1)
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 40)
                                    .allowsHitTesting(false)
                            }

                            Text(L10n.currentLanguage == "de"
                                 ? "Mit der Unterschrift bestätigt dein Buddy die Tauchgangsdaten."
                                 : "By signing, your buddy confirms the dive details.")
                                .font(.system(size: 11))
                                .foregroundColor(.textDim)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(L10n.currentLanguage == "de" ? "Unterschrift" : "Signature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.currentLanguage == "de" ? "Abbrechen" : "Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white.opacity(0.7))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        saveSignature()
                    } label: {
                        Text(L10n.currentLanguage == "de" ? "Speichern" : "Save")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(canSave ? .seafoam : .white.opacity(0.25))
                    }
                    .disabled(!canSave)
                }
            }
            .toolbarBackground(Color.deepOcean, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            guard !didApplyPrefill else { return }
            didApplyPrefill = true
            if let n = prefilledName, !n.isEmpty { buddyName = n }
            if let p = prefilledPadi, !p.isEmpty { buddyPadi = p }
        }
    }

    // ═══════════════════════════════════════

    private var diveHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("#\(dive.number)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.seafoam)
                Text(dive.formattedDate)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
            Text(dive.siteName)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
            Text(dive.siteLocation)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.5))

            HStack(spacing: 14) {
                stat(icon: "arrow.down", text: "\(String(format: "%.0f", dive.maxDepth)) m")
                stat(icon: "clock", text: "\(dive.totalTime) min")
                stat(icon: "thermometer.medium", text: "\(String(format: "%.0f", dive.waterTempSurface))°C")
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.cardBorder, lineWidth: 1))
    }

    private func stat(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10)).foregroundColor(.white.opacity(0.4))
            Text(text).font(.system(size: 12, weight: .semibold)).foregroundColor(.white.opacity(0.7))
        }
    }

    // MARK: - Save

    private func saveSignature() {
        guard canSave else { return }
        let trimmedName = buddyName.trimmingCharacters(in: .whitespaces)
        let trimmedPadi = buddyPadi.trimmingCharacters(in: .whitespaces)

        // Render current strokes to PNG using the captured canvas size
        let renderSize = canvasSize.width > 0 && canvasSize.height > 0
            ? canvasSize
            : CGSize(width: 600, height: 220)
        let pngData = SignatureRenderer.pngData(strokes: strokes, size: renderSize)

        let method = (prefilledQRHash?.isEmpty == false) ? "qr" : "finger"
        let sig = DiveSignature(
            buddyName: trimmedName,
            buddyPadiNumber: trimmedPadi,
            method: method,
            signedAt: .now,
            isVerified: false
        )
        sig.signatureImageData = pngData
        if let hash = prefilledQRHash, !hash.isEmpty {
            sig.qrHash = hash
        }
        ctx.insert(sig)
        // SwiftData maintains the inverse relationship automatically — setting
        // either side is enough. Using the array side here so UI observers
        // that watch dive.signatures update immediately.
        if dive.signatures == nil { dive.signatures = [] }
        dive.signatures?.append(sig)

        dismiss()
    }
}

// ═══════════════════════════════════════
// MARK: - Signature Display
// ═══════════════════════════════════════

/// Read-only card showing a stored signature. Used in DiveDetailView's Sign tab.
struct SignatureCard: View {
    let signature: DiveSignature

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.seafoam)
                VStack(alignment: .leading, spacing: 1) {
                    Text(signature.buddyName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    HStack(spacing: 6) {
                        if !signature.buddyPadiNumber.isEmpty {
                            Text("PADI #\(signature.buddyPadiNumber)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.seafoam.opacity(0.8))
                        }
                        Text(signature.signedAt.formatted(.dateTime.day().month().year().hour().minute()))
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
                Spacer()
                Text(methodBadge)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.oceanBlue)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Color.oceanBlue.opacity(0.15)))
                    .overlay(Capsule().stroke(Color.oceanBlue.opacity(0.3), lineWidth: 1))
            }

            if let data = signature.signatureImageData, let uiImg = UIImage(data: data) {
                Image(uiImage: uiImg)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 120)
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08), lineWidth: 1))
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.seafoam.opacity(0.15), lineWidth: 1))
    }

    private var methodBadge: String {
        switch signature.method {
        case "qr":    return "QR"
        case "link":  return L10n.currentLanguage == "de" ? "LINK" : "LINK"
        default:      return L10n.currentLanguage == "de" ? "FINGER" : "FINGER"
        }
    }
}
