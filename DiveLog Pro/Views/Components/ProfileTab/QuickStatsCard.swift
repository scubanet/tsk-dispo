import SwiftUI
import SwiftData

/// Compact stats row: total dive count, total bottom-time, earned signatures.
/// Stateless — takes the dive list from ProfileTab via parameter.
struct QuickStatsCard: View {
    let dives: [Dive]

    var body: some View {
        let totalDives = dives.count
        let totalHours = dives.reduce(0) { $0 + $1.totalTime } / 60
        let signaturesEarned = dives.reduce(0) { $0 + ($1.signatures?.count ?? 0) }

        return HStack(spacing: DSSpacing.s) {
            miniStat(value: "\(totalDives)",
                     label: L10n.currentLanguage == "de" ? "Tauchgänge" : "Dives",
                     tint: .appAccent)
            miniStat(value: "\(totalHours)h",
                     label: L10n.currentLanguage == "de" ? "Unter Wasser" : "Underwater",
                     tint: .appSuccess)
            miniStat(value: "\(signaturesEarned)",
                     label: L10n.currentLanguage == "de" ? "Signaturen" : "Signatures",
                     tint: .appEmphasis)
        }
    }

    private func miniStat(value: String, label: String, tint: Color) -> some View {
        VStack(spacing: DSSpacing.xs) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DSSpacing.m + 2)
        .glassCard(cornerRadius: DSRadius.m)
    }
}
