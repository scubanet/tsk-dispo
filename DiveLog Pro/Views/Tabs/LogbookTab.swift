import SwiftUI
import SwiftData

struct LogbookTab: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(DeleteUndoManager.self) private var undoManager
    @Query(sort: \Dive.date, order: .reverse) private var dives: [Dive]
    @State private var showingDiveCreate = false
    @State private var showingPoolCreate = false
    @State private var showingQuickLog = false
    @State private var searchText = ""
    @State private var diveToDelete: Dive?

    /// Same as `dives` minus whatever is in pending-delete limbo.
    private var visibleDives: [Dive] {
        guard let pending = undoManager.pendingDive else { return dives }
        return dives.filter { $0.persistentModelID != pending.persistentModelID }
    }

    var filtered: [Dive] {
        let source = visibleDives
        if searchText.isEmpty { return source }
        let q = searchText.lowercased()
        return source.filter {
            $0.siteName.lowercased().contains(q)   ||
            $0.siteLocation.lowercased().contains(q) ||
            $0.buddyNames.lowercased().contains(q) ||
            $0.notes.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Soft hero tint at the top, fades into system background
                HeroBackground()

                ScrollView {
                    LazyVStack(spacing: DSSpacing.m + 2) {
                        // Summary header — lightweight stat strip
                        if !visibleDives.isEmpty && searchText.isEmpty {
                            summaryHeader
                                .padding(.horizontal, DSSpacing.xl)
                                .padding(.top, DSSpacing.xs)
                        }

                        ForEach(filtered) { dive in
                            NavigationLink(value: dive) {
                                DiveCard(dive: dive)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, DSSpacing.xl)
                            .contextMenu {
                                Button(role: .destructive) {
                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                    generator.impactOccurred()
                                    diveToDelete = dive
                                } label: {
                                    Label(
                                        L10n.currentLanguage == "de" ? "Löschen" : "Delete",
                                        systemImage: "trash"
                                    )
                                }
                            }
                        }

                        if filtered.isEmpty && !searchText.isEmpty {
                            emptySearch
                        }

                        if visibleDives.isEmpty {
                            emptyState
                        }
                    }
                    .padding(.top, DSSpacing.s)
                    .padding(.bottom, 120) // room for FAB + tab bar
                }
                .scrollContentBackground(.hidden)

                // Floating Action Button + Undo Snackbar
                VStack(spacing: DSSpacing.s) {
                    Spacer()

                    // Undo-Snackbar — appears when a dive is pending delete.
                    if let pending = undoManager.pendingDive,
                       let scheduledAt = undoManager.scheduledAt {
                        undoSnackbar(for: pending, scheduledAt: scheduledAt)
                            .padding(.horizontal, DSSpacing.xl)
                            .transition(
                                .move(edge: .bottom).combined(with: .opacity)
                            )
                    }

                    HStack {
                        Spacer()
                        Menu {
                            Button {
                                showingDiveCreate = true
                            } label: {
                                Label(L10n.currentLanguage == "de" ? "Tauchgang" : "Dive",
                                      systemImage: "water.waves")
                            }
                            Button {
                                showingPoolCreate = true
                            } label: {
                                Label(L10n.currentLanguage == "de" ? "Pool-Session" : "Pool Session",
                                      systemImage: "figure.pool.swim")
                            }
                            Button {
                                showingQuickLog = true
                            } label: {
                                Label(L10n.currentLanguage == "de" ? "Quick-Log" : "Quick Log",
                                      systemImage: "bolt.fill")
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 56, height: 56)
                                .background(Circle().fill(Color.appAccent))
                                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                        } primaryAction: {
                            showingDiveCreate = true   // Short tap = dive
                        }
                        .padding(.trailing, DSSpacing.xl)
                        .padding(.bottom, DSSpacing.s)
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.85),
                           value: undoManager.pendingDive?.persistentModelID)
            }
            .navigationTitle(L10n.tabLogbook)
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: L10n.searchPlaceholder)
            .navigationDestination(for: Dive.self) { dive in
                DiveDetailView(dive: dive)
            }
            .sheet(isPresented: $showingDiveCreate) {
                DiveFormView(mode: .new)
            }
            .sheet(isPresented: $showingPoolCreate) {
                PoolSessionCreateView()
            }
            .sheet(isPresented: $showingQuickLog) {
                QuickLogView()
            }
            .confirmationDialog(
                confirmTitle(for: diveToDelete),
                isPresented: Binding(
                    get: { diveToDelete != nil },
                    set: { if !$0 { diveToDelete = nil } }
                ),
                titleVisibility: .visible,
                presenting: diveToDelete
            ) { dive in
                Button(role: .destructive) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        undoManager.schedule(dive, in: modelContext)
                    }
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    diveToDelete = nil
                } label: {
                    Text(L10n.currentLanguage == "de"
                         ? "TG #\(dive.number) löschen"
                         : "Delete dive #\(dive.number)")
                }
                Button(L10n.currentLanguage == "de" ? "Abbrechen" : "Cancel",
                       role: .cancel) {
                    diveToDelete = nil
                }
            } message: { dive in
                Text(confirmMessage(for: dive))
            }
            // Seed-Code absichtlich deaktiviert. In einer CloudKit-Umgebung
            // bedeutet `dives.isEmpty` beim App-Start oft nur "Sync hat noch
            // nicht stattgefunden" — automatisches Seeden würde dann bei jedem
            // neuen Device Dubletten erzeugen, sobald der echte Sync einläuft.
            // Wer Sample-Daten zum Testen will, macht das über Profile →
            // Datenverwaltung → "Beispieldaten laden" (später).
        }
    }

    // ─── Summary header ───────────────────

    private var summaryHeader: some View {
        HStack(spacing: DSSpacing.s) {
            summaryTile(
                value: "\(visibleDives.count)",
                label: L10n.currentLanguage == "de" ? "TGs" : "Dives",
                symbol: "water.waves",
                tint: .appAccent
            )
            summaryTile(
                value: String(format: "%.0fh", Double(visibleDives.map(\.totalTime).reduce(0,+)) / 60.0),
                label: L10n.currentLanguage == "de" ? "Unterwasser" : "Underwater",
                symbol: "clock",
                tint: .appSuccess
            )
            summaryTile(
                value: String(format: "%.0fm", visibleDives.map(\.maxDepth).max() ?? 0),
                label: L10n.currentLanguage == "de" ? "Tiefster" : "Deepest",
                symbol: "arrow.down.to.line",
                tint: .appEmphasis
            )
        }
    }

    private func summaryTile(value: String, label: String, symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(.primary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DSSpacing.m)
        .glassCard(cornerRadius: DSRadius.m)
    }

    // ─── Empty states ─────────────────────

    private var emptySearch: some View {
        VStack(spacing: DSSpacing.m) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.tertiary)
            Text(L10n.currentLanguage == "de" ? "Keine TGs gefunden" : "No dives found")
                .font(.headline)
                .foregroundStyle(.primary)
            Text(L10n.currentLanguage == "de" ? "Versuch einen anderen Suchbegriff" : "Try a different search term")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // ─── Undo Snackbar ────────────────────

    private func undoSnackbar(for dive: Dive, scheduledAt: Date) -> some View {
        // Live-ticking progress that drains from 1.0 → 0.0 over graceSeconds.
        TimelineView(.periodic(from: scheduledAt, by: 0.05)) { ctx in
            let elapsed = ctx.date.timeIntervalSince(scheduledAt)
            let progress = max(0, 1 - (elapsed / undoManager.graceSeconds))

            VStack(spacing: 0) {
                HStack(spacing: DSSpacing.m) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(L10n.currentLanguage == "de"
                             ? "TG gelöscht"
                             : "Dive deleted")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text(L10n.currentLanguage == "de"
                             ? "#\(dive.number) · \(dive.siteName)"
                             : "#\(dive.number) · \(dive.siteName)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: DSSpacing.s)

                    Button {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            undoManager.undo()
                        }
                    } label: {
                        Text(L10n.currentLanguage == "de" ? "Rückgängig" : "Undo")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.appAccent)
                            .padding(.horizontal, DSSpacing.m)
                            .padding(.vertical, DSSpacing.xs + 2)
                            .background(
                                Capsule().fill(Color.appAccent.opacity(0.12))
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, DSSpacing.m)
                .padding(.vertical, DSSpacing.s + 2)

                // Progress bar — drains as time runs out
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.hairline.opacity(0.3))
                        Rectangle()
                            .fill(Color.appAccent.opacity(0.7))
                            .frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 2)
            }
            .background(
                RoundedRectangle(cornerRadius: DSRadius.m)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.m)
                    .stroke(Color.hairline.opacity(0.5), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.m))
            .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        }
    }

    private var emptyState: some View {
        VStack(spacing: DSSpacing.m) {
            Image(systemName: "water.waves")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Color.appAccent.opacity(0.6))
            Text(L10n.currentLanguage == "de" ? "Noch keine Tauchgänge" : "No dives yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
            Text(L10n.currentLanguage == "de"
                 ? "Tippe auf +, um deinen ersten TG zu loggen"
                 : "Tap + to log your first dive")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DSSpacing.xxl)
        .padding(.top, 80)
    }

    // MARK: - Delete confirmation helpers
    private func confirmTitle(for dive: Dive?) -> String {
        guard let dive else { return "" }
        return L10n.currentLanguage == "de" ? "Tauchgang löschen?" : "Delete dive?"
    }

    private func confirmMessage(for dive: Dive) -> String {
        let assessments = dive.skillCompletions?.count ?? 0
        let studentCount = dive.students?.count ?? 0
        let isDE = L10n.currentLanguage == "de"
        if assessments > 0 {
            return isDE
                ? "\(dive.siteName) vom \(dive.formattedDate) wird unwiderruflich gelöscht. Das synct auch auf all deine Geräte.\n\n\(assessments) Skill-Assessments für \(studentCount) Schüler werden ebenfalls gelöscht."
                : "\(dive.siteName) on \(dive.formattedDate) will be permanently deleted. This also syncs to all your devices.\n\n\(assessments) skill assessments for \(studentCount) students will also be deleted."
        }
        return isDE
            ? "\(dive.siteName) vom \(dive.formattedDate) wird unwiderruflich gelöscht. Das synct auch auf all deine Geräte."
            : "\(dive.siteName) on \(dive.formattedDate) will be permanently deleted. This also syncs to all your devices."
    }

}
