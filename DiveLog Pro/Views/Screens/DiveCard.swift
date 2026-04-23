import SwiftUI

struct DiveCard: View {
    let dive: Dive

    var body: some View {
        VStack(spacing: 0) {
            // ─── Depth profile header ──────────────
            ZStack(alignment: .topTrailing) {
                if !dive.depthProfile.isEmpty {
                    DepthProfileChart(
                        data: dive.depthProfile,
                        maxDepth: dive.maxDepth,
                        height: 86,
                        compact: true
                    )
                    .overlay(
                        LinearGradient(
                            colors: [.clear, Color.surfaceElevated.opacity(0.4)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                } else {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.appAccent.opacity(0.12),
                                    Color.seafoam.opacity(0.06)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 86)
                }

                // Dive number badge — thin glass pill
                HStack(spacing: DSSpacing.xs) {
                    if dive.isHighlight {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.appEmphasis)
                    }
                    Text("#\(dive.number)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, DSSpacing.m)
                .padding(.vertical, DSSpacing.xs + 2)
                .background(
                    Capsule().fill(.ultraThinMaterial)
                )
                .overlay(
                    Capsule().stroke(Color.hairline.opacity(0.4), lineWidth: 0.5)
                )
                .padding(DSSpacing.m)
            }
            .frame(height: 86)
            .clipped()

            // ─── Card body ─────────────────────────
            VStack(alignment: .leading, spacing: DSSpacing.s + 2) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dive.siteName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text("\(dive.siteLocation) • \(dive.formattedDate)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: DSSpacing.s)
                    Text(dive.feelingEmoji)
                        .font(.system(size: 22))
                }

                // Stats row
                HStack(spacing: 0) {
                    cardStat(L10n.currentLanguage == "de" ? "Tiefe" : "Depth",
                             String(format: "%.0fm", dive.maxDepth), accent: true)
                    statDivider
                    cardStat(L10n.currentLanguage == "de" ? "Zeit" : "Time",
                             "\(dive.totalTime)min")
                    statDivider
                    cardStat("Temp", String(format: "%.0f°C", dive.waterTempSurface))
                    statDivider
                    cardStat("Tank", "\(dive.tankStartBar)→\(dive.tankEndBar)")
                }

                // Type pill + marine life + signature
                HStack(spacing: DSSpacing.xs + 2) {
                    HStack(spacing: 4) {
                        Image(systemName: dive.diveTypeIcon).font(.system(size: 10))
                        Text(DiveTypeOption.all.first { $0.id == dive.diveType }?.label
                             ?? dive.diveType)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(Color.appAccent)
                    .padding(.horizontal, DSSpacing.s)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(Color.appAccent.opacity(0.10))
                    )

                    ForEach(dive.marineLife.prefix(2), id: \.self) { species in
                        Text(species)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(Color.surfaceCard)
                            )
                            .overlay(
                                Capsule().stroke(Color.hairline.opacity(0.4),
                                                 lineWidth: 0.5)
                            )
                    }

                    Spacer(minLength: 0)

                    if !(dive.signatures ?? []).isEmpty {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.appSuccess)
                    }
                }
            }
            .padding(DSSpacing.l)
        }
        .glassCard(cornerRadius: DSRadius.xl)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.xl, style: .continuous))
    }

    // ─── Helpers ──────────────────────────

    private func cardStat(_ label: String, _ value: String, accent: Bool = false) -> some View {
        VStack(spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(accent ? Color.appAccent : .primary)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.hairline.opacity(0.5))
            .frame(width: 0.5, height: 24)
    }
}
