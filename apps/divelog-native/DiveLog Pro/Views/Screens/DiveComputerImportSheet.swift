import SwiftUI
import SwiftData

/// Modal sheet that presents the result of parsing a dive-computer
/// file (.uddf or .fit) and lets the user pick which dives to import,
/// with a strategy for resolving duplicates. The loading-state copy
/// adapts to the file's format based on its extension.
struct DiveComputerImportSheet: View {
    let fileURL: URL
    let onCompletion: (Int, Int) -> Void  // (inserted, skipped) — used for the success toast

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Dive.date, order: .reverse) private var existingDives: [Dive]
    @Query private var profiles: [DiverProfile]

    @State private var loading = true
    @State private var error: String?
    @State private var generatorName: String = ""
    @State private var candidates: [ImportCandidate] = []
    @State private var strategy: ConflictStrategy = .skip
    @State private var committing = false

    var body: some View {
        NavigationStack {
            ZStack {
                HeroBackground()
                content
            }
            .navigationTitle(L10n.currentLanguage == "de" ? "Import" : "Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.currentLanguage == "de" ? "Abbrechen" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        commit()
                    } label: {
                        if committing { ProgressView() }
                        else {
                            Text(L10n.currentLanguage == "de"
                                 ? "Importieren (\(selectedCount))"
                                 : "Import (\(selectedCount))")
                        }
                    }
                    .disabled(loading || selectedCount == 0 || committing)
                }
            }
            .task { await load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if loading {
            VStack(spacing: DSSpacing.l) {
                ProgressView()
                Text(L10n.currentLanguage == "de"
                     ? "\(formatName)-Datei wird gelesen…"
                     : "Reading \(formatName) file…")
                    .foregroundStyle(.secondary)
            }
        } else if let error {
            VStack(spacing: DSSpacing.l) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)
                Text(error)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DSSpacing.xl)
            }
        } else {
            VStack(alignment: .leading, spacing: DSSpacing.l) {
                summary
                strategyPicker
                List($candidates) { $c in
                    candidateRow($c)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .padding(.top, DSSpacing.s)
        }
    }

    private var summary: some View {
        let total = candidates.count
        let dupes = candidates.filter { $0.conflictWith != nil }.count
        let news  = total - dupes
        return VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text(generatorName.isEmpty
                 ? (L10n.currentLanguage == "de" ? "Unbekannte Quelle" : "Unknown source")
                 : (L10n.currentLanguage == "de" ? "Quelle: \(generatorName)" : "Source: \(generatorName)"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(L10n.currentLanguage == "de"
                 ? "\(total) Tauchgänge gefunden"
                 : "\(total) dives found")
                .font(.headline)
            Text(L10n.currentLanguage == "de"
                 ? "\(news) neu · \(dupes) Duplikate"
                 : "\(news) new · \(dupes) duplicates")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, DSSpacing.l)
    }

    private var strategyPicker: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text(L10n.currentLanguage == "de" ? "Bei Duplikaten" : "On duplicates")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Picker("Strategie", selection: $strategy) {
                ForEach(ConflictStrategy.allCases) { s in
                    Text(s.label).tag(s)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, DSSpacing.l)
    }

    private func candidateRow(_ c: Binding<ImportCandidate>) -> some View {
        let dive = c.wrappedValue.dive
        let conflict = c.wrappedValue.conflictWith
        return HStack(spacing: DSSpacing.m) {
            Image(systemName: c.wrappedValue.selected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(c.wrappedValue.selected ? Color.appAccent : Color.secondary)
                .onTapGesture { c.wrappedValue.selected.toggle() }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(formattedDate(dive.date))
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(String(format: "%.1fm · %dmin", dive.maxDepth, dive.totalTime))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    if let conflict {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption2)
                        Text(L10n.currentLanguage == "de"
                             ? "Duplikat von #\(conflict.number)"
                             : "Duplicate of #\(conflict.number)")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption2)
                        Text(L10n.currentLanguage == "de" ? "Neu" : "New")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                    if !dive.siteName.isEmpty {
                        Text("·").foregroundStyle(.tertiary)
                        Text(dive.siteName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(Color.clear)
    }

    private var selectedCount: Int {
        candidates.filter(\.selected).count
    }

    private func formattedDate(_ d: Date) -> String {
        d.formatted(.dateTime.day().month(.abbreviated).year().hour().minute())
    }

    /// Human-readable name of the source format, derived from the file's
    /// extension. Used in the loading-state label so users see which
    /// format is being parsed.
    private var formatName: String {
        fileURL.pathExtension.lowercased() == "fit" ? "FIT" : "UDDF"
    }

    // MARK: - Actions

    private func load() async {
        do {
            let (file, cands) = try await UDDFImportCoordinator.prepareImport(
                from: fileURL, existingDives: existingDives)
            generatorName = file.generator
            candidates = cands
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
        }
        loading = false
    }

    private func commit() {
        guard let profile = profiles.first else { return }
        committing = true
        let (inserted, skipped) = UDDFImportCoordinator.commitImport(
            candidates: candidates,
            strategy: strategy,
            context: ctx,
            profile: profile)
        committing = false
        onCompletion(inserted, skipped)
        dismiss()
    }
}
