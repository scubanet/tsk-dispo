import SwiftUI
import SwiftData

/// Header card showing the user's profile: avatar, name, PADI level,
/// contact info preview, edit-tap target.
///
/// Stateless except for its tap-to-edit callback. Uses xxl padding for
/// the hero placement at the top of the Profile tab — does NOT apply
/// .profileCardStyle() because the standard padding (DSSpacing.l) would
/// be too tight for this card's visual emphasis.
struct ProfileCard: View {
    let profile: DiverProfile?
    let onEdit: () -> Void

    var body: some View {
        VStack(spacing: DSSpacing.m) {
            // Avatar
            Group {
                if let data = profile?.profileImageData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 92, height: 92)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.appAccent.opacity(0.3), lineWidth: 2))
                } else {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 92, height: 92)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.tertiary)
                        )
                        .overlay(Circle().stroke(Color.hairline, lineWidth: 0.5))
                }
            }

            // Name
            Text(displayName)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            // Cert
            Text(certTitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.appAccent)

            // PADI # + email
            VStack(spacing: 2) {
                if let padi = profile?.padiNumber, !padi.isEmpty {
                    Text("PADI #\(padi)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                if let email = profile?.email, !email.isEmpty {
                    Text(email)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }

            // CTA if empty
            if isProfileEmpty {
                Button {
                    onEdit()
                } label: {
                    Text(L10n.currentLanguage == "de" ? "Profil einrichten" : "Set up profile")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.surfaceElevated)
                        .padding(.horizontal, 18).padding(.vertical, 9)
                        .background(Capsule().fill(Color.appAccent))
                }
                .buttonStyle(.plain)
                .padding(.top, DSSpacing.xs)
            }
        }
        .frame(maxWidth: .infinity)
        // profileCard intentionally uses xxl padding (32 pt) — it is the
        // hero identity card and needs extra breathing room. Sub-cards use
        // .profileCardStyle() which encodes DSSpacing.l (16 pt).
        .padding(DSSpacing.xxl)
        .glassCard(cornerRadius: DSRadius.xl)
    }

    // ─── Single-use helpers moved from ProfileTab ───

    private var displayName: String {
        if let n = profile?.name, !n.trimmingCharacters(in: .whitespaces).isEmpty {
            return n
        }
        return L10n.currentLanguage == "de" ? "Dein Name" : "Your Name"
    }

    private var certTitle: String {
        let level = profile?.certLevel ?? "OWD"
        switch level {
        case "CD":       return "PADI Course Director"
        case "IDC Staff": return "PADI IDC Staff Instructor"
        case "MSDT":     return "PADI Master Scuba Diver Trainer"
        case "OWSI":     return "PADI Open Water Scuba Instructor"
        case "DM":       return "PADI Divemaster"
        case "Rescue":   return "PADI Rescue Diver"
        case "AOWD":     return "PADI Advanced Open Water"
        case "OWD":      return "PADI Open Water Diver"
        default:         return level
        }
    }

    private var isProfileEmpty: Bool {
        guard let p = profile else { return true }
        return p.name.trimmingCharacters(in: .whitespaces).isEmpty
            && p.padiNumber.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
