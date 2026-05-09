import SwiftUI
import SwiftData

struct JournalTab: View {
    @Query(sort: \Dive.date, order: .reverse) private var dives: [Dive]

    var journalDives: [Dive] {
        dives.filter { !$0.notes.isEmpty || !$0.photoFilenames.isEmpty || $0.isHighlight }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                HeroBackground()

                ScrollView {
                    LazyVStack(spacing: DSSpacing.xl) {
                        ForEach(journalDives) { dive in
                            NavigationLink(value: dive) {
                                JournalCard(dive: dive)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, DSSpacing.xl)
                        }

                        if journalDives.isEmpty { emptyJournal }
                    }
                    .padding(.top, DSSpacing.s)
                    .padding(.bottom, DSSpacing.xxxl)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(L10n.tabJournal)
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: Dive.self) { dive in
                DiveDetailView(dive: dive)
            }
        }
    }

    private var emptyJournal: some View {
        VStack(spacing: DSSpacing.m) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.tertiary)
            Text(L10n.currentLanguage == "de" ? "Noch keine Journal-Einträge" : "No journal entries yet")
                .font(.headline)
                .foregroundStyle(.primary)
            Text(L10n.currentLanguage == "de"
                 ? "Füge Notizen, Fotos oder Highlights zu deinen TGs hinzu"
                 : "Add notes, photos or highlights to your dives")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DSSpacing.xxl)
        .padding(.top, 80)
    }
}

// ═══════════════════════════════════════
// MARK: - Journal Card (light + glass)
// ═══════════════════════════════════════

struct JournalCard: View {
    let dive: Dive

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.m) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: DSSpacing.s) {
                        if dive.isHighlight {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.appEmphasis)
                        }
                        Text("#\(dive.number)")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    Text(dive.date.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(dive.feelingEmoji).font(.system(size: 28))
            }

            Text(dive.siteName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            Text(dive.siteLocation)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let cover = dive.photoFilenames.first {
                ZStack(alignment: .bottomTrailing) {
                    GeometryReader { geo in
                        DivePhotoThumbnail(
                            filename: cover,
                            dive: dive,
                            width: geo.size.width,
                            height: 220,
                            cornerRadius: DSRadius.m
                        )
                    }
                    .frame(height: 220)
                    if dive.photoFilenames.count > 1 {
                        HStack(spacing: 4) {
                            Image(systemName: "photo.stack.fill")
                                .font(.system(size: 10))
                            Text("+\(dive.photoFilenames.count - 1)")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, DSSpacing.s + 2).padding(.vertical, 5)
                        .background(
                            Capsule().fill(.ultraThinMaterial)
                        )
                        .overlay(
                            Capsule().fill(Color.black.opacity(0.35))
                        )
                        .padding(DSSpacing.s + 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            if !dive.depthProfile.isEmpty {
                DepthProfileChart(data: dive.depthProfile, maxDepth: dive.maxDepth, height: 60, compact: true)
                    .clipShape(RoundedRectangle(cornerRadius: DSRadius.s, style: .continuous))
            }

            if !dive.notes.isEmpty {
                Text(dive.notes)
                    .font(.callout)
                    .foregroundStyle(.primary.opacity(0.85))
                    .lineSpacing(4)
                    .lineLimit(4)
            }

            if !dive.marineLife.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(dive.marineLife.prefix(5), id: \.self) { species in
                        MarineLifeChip(species: species)
                    }
                }
            }

            HStack(spacing: DSSpacing.l) {
                miniStat(icon: "arrow.down", value: String(format: "%.0fm", dive.maxDepth))
                miniStat(icon: "clock", value: "\(dive.totalTime)min")
                miniStat(icon: "thermometer.medium", value: String(format: "%.0f°C", dive.waterTempSurface))
                Spacer()
                if dive.rating > 0 {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= dive.rating ? "star.fill" : "star")
                                .font(.system(size: 10))
                                .foregroundStyle(star <= dive.rating ? Color.appEmphasis : Color.hairline)
                        }
                    }
                }
            }
        }
        .padding(DSSpacing.l + 2)
        .glassCard(cornerRadius: DSRadius.xl)
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.xl, style: .continuous)
                .stroke(
                    dive.isHighlight ? Color.appEmphasis.opacity(0.4) : .clear,
                    lineWidth: dive.isHighlight ? 1.5 : 0
                )
        )
    }

    private func miniStat(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }
}
