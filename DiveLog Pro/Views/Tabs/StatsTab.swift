import SwiftUI
import SwiftData
import Charts

struct StatsTab: View {
    @Query(sort: \Dive.date, order: .reverse) private var dives: [Dive]
    @Query private var profiles: [DiverProfile]

    // ═══════════════════════════════════════
    // MARK: - Computed Stats
    // ═══════════════════════════════════════

    private var totalDives: Int { dives.count }
    private var careerNumber: Int { dives.first?.number ?? dives.count }

    private var totalMinutes: Int { dives.reduce(0) { $0 + $1.totalTime } }
    private var totalHours: Double { Double(totalMinutes) / 60.0 }

    private var avgDepth: Double {
        dives.isEmpty ? 0 : dives.reduce(0.0) { $0 + $1.maxDepth } / Double(dives.count)
    }
    private var deepest: Double { dives.map(\.maxDepth).max() ?? 0 }
    private var longest: Int { dives.map(\.totalTime).max() ?? 0 }

    private var avgSac: Double {
        let sacs = dives.filter { $0.sacRate > 0 }
        return sacs.isEmpty ? 0 : sacs.reduce(0.0) { $0 + $1.sacRate } / Double(sacs.count)
    }
    private var avgTemp: Double {
        dives.isEmpty ? 0 : dives.reduce(0.0) { $0 + $1.waterTempSurface } / Double(dives.count)
    }
    private var uniqueSites: Int { Set(dives.map(\.siteName).filter { !$0.isEmpty }).count }
    private var uniqueSpecies: [String] { Array(Set(dives.flatMap(\.marineLife))).sorted() }
    private var uniqueBuddies: [String] {
        Array(Set(dives.flatMap(\.buddyList)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }))
            .sorted()
    }

    private var coldDives: Int { dives.filter { $0.waterTempSurface > 0 && $0.waterTempSurface < 15 }.count }
    private var deepDives: Int { dives.filter { $0.maxDepth >= 30 }.count }
    private var nightDives: Int { dives.filter { $0.diveType == "night" }.count }
    private var highlightDives: Int { dives.filter(\.isHighlight).count }

    private var divesPerYear: [(year: Int, count: Int)] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: dives) { calendar.component(.year, from: $0.date) }
        return grouped.map { (year: $0.key, count: $0.value.count) }.sorted { $0.year < $1.year }
    }

    private func topSites(_ limit: Int = 5) -> [(name: String, count: Int)] {
        let grouped = Dictionary(grouping: dives.filter { !$0.siteName.isEmpty }, by: \.siteName)
        return grouped
            .map { (name: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
            .prefix(limit)
            .map { $0 }
    }

    private func topBuddies(_ limit: Int = 5) -> [(name: String, count: Int)] {
        var counts: [String: Int] = [:]
        for dive in dives {
            for buddy in dive.buddyList {
                let name = buddy.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { continue }
                counts[name, default: 0] += 1
            }
        }
        return counts.map { (name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
            .prefix(limit).map { $0 }
    }

    private func topSpecies(_ limit: Int = 8) -> [(name: String, count: Int)] {
        var counts: [String: Int] = [:]
        for dive in dives {
            for species in dive.marineLife { counts[species, default: 0] += 1 }
        }
        return counts.map { (name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
            .prefix(limit).map { $0 }
    }

    // ═══════════════════════════════════════
    // MARK: - Body
    // ═══════════════════════════════════════

    var body: some View {
        NavigationStack {
            ZStack {
                HeroBackground()

                ScrollView {
                    if dives.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: DSSpacing.l) {
                            heroCard
                            quickStatsGrid
                            if divesPerYear.count >= 2 { yearlyChart }
                            depthChart
                            specialtyCountsGrid
                            topSitesSection
                            topBuddiesSection
                            topSpeciesSection
                        }
                        .padding(.horizontal, DSSpacing.xl)
                        .padding(.top, DSSpacing.s)
                        .padding(.bottom, DSSpacing.xxxl)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(L10n.tabStats)
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // ═══════════════════════════════════════

    private var emptyState: some View {
        VStack(spacing: DSSpacing.m) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.tertiary)
            Text(L10n.currentLanguage == "de" ? "Noch keine Statistiken" : "No statistics yet")
                .font(.headline)
                .foregroundStyle(.primary)
            Text(L10n.currentLanguage == "de"
                 ? "Logge deine ersten TGs, um deine Trends zu sehen."
                 : "Log your first dives to see your trends.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DSSpacing.xxl)
        .padding(.top, 120)
    }

    // ═══════════════════════════════════════
    // MARK: - Hero Card
    // ═══════════════════════════════════════

    private var heroCard: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.seafoam.opacity(0.25), .clear],
                        center: .center, startRadius: 0, endRadius: 100
                    )
                )
                .frame(width: 200, height: 200).offset(x: 80, y: 30)

            VStack(spacing: DSSpacing.xs + 2) {
                Text("\(careerNumber)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appAccent)
                    .contentTransition(.numericText())
                Text(L10n.totalDivesCount.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                Text("\(String(format: "%.0f", totalHours)) \(L10n.hoursUnderwater)")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.8))
                    .padding(.top, DSSpacing.xs)
            }
            .padding(.vertical, DSSpacing.xxl + 4)
        }
        .frame(maxWidth: .infinity)
        .glassCard(cornerRadius: DSRadius.xxl)
    }

    // ═══════════════════════════════════════
    // MARK: - Quick Stats Grid
    // ═══════════════════════════════════════

    private var quickStatsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DSSpacing.m) {
            StatCard(label: L10n.avgDepth, value: String(format: "%.0f", avgDepth), unit: "m", accent: true)
            StatCard(label: L10n.deepestDive, value: String(format: "%.1f", deepest), unit: "m")
            StatCard(label: L10n.avgSac, value: avgSac > 0 ? String(format: "%.1f", avgSac) : "—", unit: avgSac > 0 ? "l/min" : "")
            StatCard(label: L10n.currentLanguage == "de" ? "Ø Temp" : "Avg Temp", value: String(format: "%.0f", avgTemp), unit: "°C")
            StatCard(label: L10n.longestDive, value: "\(longest)", unit: "min")
            StatCard(label: L10n.currentLanguage == "de" ? "Tauchplätze" : "Dive Sites", value: "\(uniqueSites)")
        }
    }

    // ═══════════════════════════════════════
    // MARK: - Yearly Trend Chart
    // ═══════════════════════════════════════

    private var yearlyChart: some View {
        VStack(alignment: .leading, spacing: DSSpacing.m) {
            DSSectionLabel(text: L10n.currentLanguage == "de" ? "TGs pro Jahr" : "Dives per Year")

            Chart {
                ForEach(divesPerYear, id: \.year) { item in
                    LineMark(
                        x: .value("Year", "\(item.year)"),
                        y: .value("Dives", item.count)
                    )
                    .foregroundStyle(Color.appAccent)
                    .interpolationMethod(.monotone)

                    AreaMark(
                        x: .value("Year", "\(item.year)"),
                        y: .value("Dives", item.count)
                    )
                    .foregroundStyle(LinearGradient(
                        colors: [Color.appAccent.opacity(0.25), Color.appAccent.opacity(0.02)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .interpolationMethod(.monotone)

                    PointMark(
                        x: .value("Year", "\(item.year)"),
                        y: .value("Dives", item.count)
                    )
                    .foregroundStyle(Color.appAccent)
                    .symbolSize(40)
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel().font(.caption2).foregroundStyle(.secondary)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel().font(.caption2).foregroundStyle(.secondary)
                    AxisGridLine().foregroundStyle(Color.hairline.opacity(0.6))
                }
            }
            .frame(height: 180)
        }
        .padding(DSSpacing.xl)
        .glassCard(cornerRadius: DSRadius.l)
    }

    // ═══════════════════════════════════════
    // MARK: - Recent Depth Chart
    // ═══════════════════════════════════════

    private var depthChart: some View {
        VStack(alignment: .leading, spacing: DSSpacing.m) {
            DSSectionLabel(text: L10n.currentLanguage == "de" ? "Letzte Tauchgänge" : "Recent Dives")

            Chart {
                ForEach(dives.prefix(10).reversed(), id: \.number) { dive in
                    BarMark(
                        x: .value("Dive", "#\(dive.number)"),
                        y: .value("Depth", dive.maxDepth)
                    )
                    .foregroundStyle(
                        dive.maxDepth > 30 ? Color.appEmphasis :
                        dive.maxDepth > 20 ? Color.appAccent : Color.appSuccess
                    )
                    .cornerRadius(6)
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel().font(.caption2).foregroundStyle(.secondary)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel().font(.caption2).foregroundStyle(.secondary)
                    AxisGridLine().foregroundStyle(Color.hairline.opacity(0.6))
                }
            }
            .frame(height: 200)

            HStack(spacing: DSSpacing.l) {
                legendDot(.appSuccess, L10n.currentLanguage == "de" ? "Flach" : "Shallow")
                legendDot(.appAccent,  L10n.currentLanguage == "de" ? "Mittel" : "Medium")
                legendDot(.appEmphasis, L10n.currentLanguage == "de" ? "Tief" : "Deep")
            }
            .frame(maxWidth: .infinity)
        }
        .padding(DSSpacing.xl)
        .glassCard(cornerRadius: DSRadius.l)
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    // ═══════════════════════════════════════
    // MARK: - Specialty Counts
    // ═══════════════════════════════════════

    private var specialtyCountsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: DSSpacing.s + 2) {
            countCard(icon: "moon.stars.fill",
                      label: L10n.currentLanguage == "de" ? "Nacht-TGs" : "Night Dives",
                      value: nightDives, color: .appAccent)
            countCard(icon: "arrow.down.to.line",
                      label: L10n.currentLanguage == "de" ? "Tief-TGs" : "Deep Dives",
                      value: deepDives, color: .appEmphasis)
            countCard(icon: "snowflake",
                      label: L10n.currentLanguage == "de" ? "Kalt-TGs" : "Cold Dives",
                      value: coldDives, color: .appSuccess)
        }
    }

    private func countCard(icon: String, label: String, value: Int, color: Color) -> some View {
        VStack(spacing: DSSpacing.s) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
            Text("\(value)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DSSpacing.l)
        .solidCard(cornerRadius: DSRadius.m)
    }

    // ═══════════════════════════════════════
    // MARK: - Top Sites / Buddies / Species
    // ═══════════════════════════════════════

    @ViewBuilder
    private var topSitesSection: some View {
        let top = topSites()
        if !top.isEmpty {
            VStack(alignment: .leading, spacing: DSSpacing.s + 2) {
                SectionTitle(title: L10n.currentLanguage == "de" ? "Top Tauchplätze" : "Top Dive Sites")
                ForEach(Array(top.enumerated()), id: \.element.name) { idx, entry in
                    rankRow(index: idx + 1, name: entry.name, count: entry.count,
                            icon: "mappin.circle.fill", color: .appEmphasis)
                }
            }
        }
    }

    @ViewBuilder
    private var topBuddiesSection: some View {
        let top = topBuddies()
        if !top.isEmpty {
            VStack(alignment: .leading, spacing: DSSpacing.s + 2) {
                SectionTitle(title: L10n.currentLanguage == "de" ? "Top Tauchpartner" : "Top Buddies")
                ForEach(Array(top.enumerated()), id: \.element.name) { idx, entry in
                    rankRow(index: idx + 1, name: entry.name, count: entry.count,
                            icon: "person.fill", color: .appAccent)
                }
            }
        }
    }

    @ViewBuilder
    private var topSpeciesSection: some View {
        let top = topSpecies()
        if !top.isEmpty {
            VStack(alignment: .leading, spacing: DSSpacing.s + 2) {
                SectionTitle(title: L10n.currentLanguage == "de" ? "Top Unterwasserwelt" : "Top Marine Life")
                FlowLayout(spacing: 6) {
                    ForEach(top, id: \.name) { entry in
                        HStack(spacing: 4) {
                            Text("🐠 \(entry.name)")
                                .font(.system(size: 12, weight: .medium))
                            Text("×\(entry.count)")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(Color.surfaceCard))
                        .overlay(Capsule().strokeBorder(Color.hairline.opacity(0.5), lineWidth: 0.5))
                    }
                }
            }
        }
    }

    // ═══════════════════════════════════════

    private func rankRow(index: Int, name: String, count: Int, icon: String, color: Color) -> some View {
        HStack(spacing: DSSpacing.m) {
            Text("\(index)")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 20)

            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(width: 24)

            Text(name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            Text("\(count)")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
            Text(L10n.currentLanguage == "de" ? "TGs" : "dives")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, DSSpacing.m + 2)
        .padding(.vertical, DSSpacing.s + 2)
        .solidCard(cornerRadius: DSRadius.m)
    }
}
