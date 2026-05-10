import SwiftUI

/// Stamp-image display card. Shows the user's digital stamp PNG and provides
/// a button to open the edit flow where a stamp can be generated or uploaded.
///
/// Read-only with respect to the model: all mutations (generate / upload)
/// happen inside the edit sheet opened via `onEdit`.
struct ProfileStampCard: View {
    let profile: DiverProfile?
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.m) {
            HStack {
                Text((L10n.currentLanguage == "de" ? "Dein digitaler Stempel" : "Your Digital Stamp").uppercased())
                    .font(.caption2.weight(.semibold))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                Spacer()
                if profile?.stampImageData != nil {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.appSuccess)
                }
            }

            if let data = profile?.stampImageData, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 110)
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: DSRadius.m))
                    .overlay(RoundedRectangle(cornerRadius: DSRadius.m).stroke(Color.hairline, lineWidth: 0.5))
            } else {
                RoundedRectangle(cornerRadius: DSRadius.m)
                    .stroke(Color.hairline, style: StrokeStyle(lineWidth: 1.5, dash: [8, 4]))
                    .frame(height: 110)
                    .overlay(
                        VStack(spacing: 6) {
                            Image(systemName: "seal")
                                .font(.system(size: 22))
                                .foregroundStyle(.tertiary)
                            Text(L10n.currentLanguage == "de" ? "Noch kein Stempel" : "No stamp yet")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text(L10n.currentLanguage == "de"
                                 ? "Über Bearbeiten generieren oder hochladen"
                                 : "Generate or upload via Edit")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                    )
            }

            Button {
                onEdit()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: profile?.stampImageData == nil ? "sparkles" : "pencil")
                    Text(profile?.stampImageData == nil
                         ? (L10n.currentLanguage == "de" ? "Stempel erstellen" : "Create Stamp")
                         : (L10n.currentLanguage == "de" ? "Stempel ändern" : "Change Stamp"))
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.appAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: DSRadius.s).fill(Color.appAccent.opacity(0.10)))
            }
            .buttonStyle(.plain)
            .disabled(profile == nil)
        }
        .profileCardStyle()
    }
}
