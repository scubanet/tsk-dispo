import SwiftUI
import SwiftData

// ═══════════════════════════════════════
// MARK: - My QR Code View
// ═══════════════════════════════════════
//
// Modal sheet that displays the user's own identity QR. Buddies scan this
// to pre-fill their details before signing on the user's device.
// Fetches the DiverProfile itself via @Query so callers don't need to pass it.
//
struct MyQRCodeView: View {
    @Query private var profiles: [DiverProfile]
    @Environment(\.dismiss) private var dismiss

    private var profile: DiverProfile? { profiles.first }

    private var identity: QRCodeService.Identity {
        QRCodeService.Identity(
            name: (profile?.name.isEmpty == false) ? profile!.name : "Diver",
            padiNumber: profile?.padiNumber ?? "",
            certLevel: profile?.certLevel ?? "OWD"
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                HeroBackground()

                ScrollView {
                    VStack(spacing: DSSpacing.xl) {
                        // ─── QR Image ─────────
                        if let img = QRCodeService.generate(identity, size: 600) {
                            Image(uiImage: img)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 280, maxHeight: 280)
                                .padding(DSSpacing.l)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: DSRadius.l))
                                .shadow(color: .black.opacity(0.3), radius: 12)
                        } else {
                            ProgressView()
                                .frame(width: 280, height: 280)
                        }

                        // ─── Identity card ────
                        VStack(spacing: DSSpacing.s) {
                            Text(identity.name)
                                .font(.system(size: 22, weight: .bold))
                                .multilineTextAlignment(.center)

                            Text(certTitle)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.appAccent)

                            if !identity.padiNumber.isEmpty {
                                Text("PADI #\(identity.padiNumber)")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(DSSpacing.l)
                        .glassCard(cornerRadius: DSRadius.l)

                        // ─── Hint ─────────────
                        Text(L10n.qrShareHint)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DSSpacing.l)
                    }
                    .padding(DSSpacing.xl)
                }
            }
            .navigationTitle(L10n.myQRTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.currentLanguage == "de" ? "Fertig" : "Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var certTitle: String {
        switch identity.certLevel {
        case "CD":        return "PADI Course Director"
        case "IDC Staff": return "PADI IDC Staff Instructor"
        case "MSDT":      return "PADI Master Scuba Diver Trainer"
        case "OWSI":      return "PADI Open Water Scuba Instructor"
        case "DM":        return "PADI Divemaster"
        case "Rescue":    return "PADI Rescue Diver"
        case "AOWD":      return "PADI Advanced Open Water"
        case "OWD":       return "PADI Open Water Diver"
        default:          return identity.certLevel
        }
    }
}
