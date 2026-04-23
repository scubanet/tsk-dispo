import SwiftUI
import SwiftData

private struct ViewerPresentation: Identifiable {
    let index: Int
    var id: Int { index }
}

struct DiveDetailView: View {
    let dive: Dive
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(DeleteUndoManager.self) private var undoManager
    @State private var activeTabIndex: Int = 0
    @State private var showEdit = false
    @State private var viewerStartIndex: Int? = nil
    @State private var showingSignatureCapture = false
    @State private var showingExport = false
    @State private var showingDeleteConfirm = false

    private var tabs: [String] {
        [L10n.overview, L10n.journal, L10n.profile, L10n.stats, L10n.gear]
    }

    private var activeTabBinding: Binding<String> {
        Binding(
            get: { tabs[activeTabIndex] },
            set: { newVal in
                if let idx = tabs.firstIndex(of: newVal) { activeTabIndex = idx }
            }
        )
    }
    
    var body: some View {
        ZStack {
            HeroBackground()

            ScrollView {
                VStack(spacing: 0) {
                    // Hero
                    ZStack(alignment: .bottomTrailing) {
                        if !dive.depthProfile.isEmpty {
                            DepthProfileChart(data: dive.depthProfile, maxDepth: dive.maxDepth, height: 220)
                                .overlay(LinearGradient(colors: [Color(uiColor: .systemBackground).opacity(0.5), .clear, Color(uiColor: .systemBackground).opacity(0.97)], startPoint: .top, endPoint: .bottom))
                        }
                        Text("DIVE #\(dive.number)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.appAccent).tracking(3)
                            .padding(.horizontal, DSSpacing.l).padding(.vertical, DSSpacing.s)
                            .background(Capsule().fill(.ultraThinMaterial))
                            .overlay(Capsule().stroke(Color.hairline, lineWidth: 0.5))
                            .padding(DSSpacing.xl)
                    }
                    
                    // Site info
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(dive.siteName).font(.system(size: 24, weight: .black)).foregroundStyle(.primary)
                            if dive.isHighlight {
                                Image(systemName: "star.fill").font(.system(size: 14)).foregroundStyle(Color.appEmphasis)
                            }
                        }
                        Text(dive.siteLocation).font(.system(size: 14)).foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            Text(dive.date.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                            Text("•")
                            Text(dive.formattedTime)
                        }
                        .font(.system(size: 13)).foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20).padding(.top, 12)
                    
                    // Tabs
                    PillTabBar(selected: activeTabBinding, tabs: tabs)
                        .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 8)

                    // Content
                    VStack(spacing: 12) {
                        switch activeTabIndex {
                        case 0: overviewContent
                        case 1: journalContent
                        case 2: profileContent
                        case 3: statsContent
                        case 4: gearContent
                        default: EmptyView()
                        }
                    }
                    .padding(.horizontal, 20).padding(.bottom, 40)
                }
            }
        }
        .fullScreenCover(item: Binding(
            get: { viewerStartIndex.map { ViewerPresentation(index: $0) } },
            set: { viewerStartIndex = $0?.index }
        )) { pres in
            PhotoViewerView(filenames: dive.photoFilenames, startIndex: pres.index)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: DSSpacing.s) {
                    Button { showingExport = true } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(.ultraThinMaterial))
                            .overlay(Circle().stroke(Color.hairline, lineWidth: 0.5))
                    }
                    Button { showEdit = true } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(.ultraThinMaterial))
                            .overlay(Circle().stroke(Color.hairline, lineWidth: 0.5))
                    }
                    Menu {
                        Button(role: .destructive) {
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            showingDeleteConfirm = true
                        } label: {
                            Label(
                                L10n.currentLanguage == "de" ? "TG löschen" : "Delete dive",
                                systemImage: "trash"
                            )
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(.ultraThinMaterial))
                            .overlay(Circle().stroke(Color.hairline, lineWidth: 0.5))
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .sheet(isPresented: $showEdit) { DiveFormView(mode: .edit(dive)) }
        .sheet(isPresented: $showingSignatureCapture) { SignatureCaptureView(dive: dive) }
        .sheet(isPresented: $showingExport) { ExportSheet(singleDive: dive) }
        .confirmationDialog(
            L10n.currentLanguage == "de" ? "Tauchgang löschen?" : "Delete dive?",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                // Defer the actual delete — LogbookTab's Undo-Snackbar will
                // appear after we dismiss, so the user can still recover.
                undoManager.schedule(dive, in: modelContext)
                dismiss()
            } label: {
                Text(L10n.currentLanguage == "de"
                     ? "TG #\(dive.number) löschen"
                     : "Delete dive #\(dive.number)")
            }
            Button(L10n.currentLanguage == "de" ? "Abbrechen" : "Cancel", role: .cancel) { }
        } message: {
            Text(L10n.currentLanguage == "de"
                 ? "\(dive.siteName) vom \(dive.formattedDate) wird unwiderruflich gelöscht. Das synct auch auf all deine Geräte."
                 : "\(dive.siteName) on \(dive.formattedDate) will be permanently deleted. This also syncs to all your devices.")
        }
    }
    
    // MARK: - Overview
    private var overviewContent: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(label: L10n.maxDepth, value: String(format: "%.1f", dive.maxDepth), unit: "m",
                         sub: "\(L10n.avgDepth): \(String(format: "%.1f", dive.avgDepth))m", accent: true)
                StatCard(label: L10n.totalTime, value: "\(dive.totalTime)", unit: "min",
                         sub: "\(L10n.bottomTime): \(dive.bottomTime)min", accent: true)
                StatCard(label: L10n.waterTempSurface, value: String(format: "%.0f", dive.waterTempSurface), unit: "°C",
                         sub: "\(L10n.waterTempBottom): \(String(format: "%.0f", dive.waterTempBottom))°C")
                StatCard(label: L10n.feeling, value: dive.feelingEmoji)
            }
            
            SectionDivider()
            SectionTitle(title: L10n.conditions)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                InfoChip(systemIcon: dive.weatherSFSymbol, label: L10n.weatherLabel, value: dive.weather.replacingOccurrences(of: "_", with: " "))
                if dive.visibility > 0 {
                    InfoChip(systemIcon: "eye.fill", label: L10n.visibilityLabel, value: "\(dive.visibility)m")
                }
                InfoChip(systemIcon: "water.waves", label: L10n.currentLabel, value: dive.current)
                InfoChip(systemIcon: "thermometer.sun.fill", label: L10n.airTempLabel, value: "\(String(format: "%.0f", dive.airTemp))°C")
                InfoChip(systemIcon: dive.diveTypeIcon, label: L10n.diveType, value: DiveTypeOption.all.first { $0.id == dive.diveType }?.label ?? dive.diveType)
                InfoChip(systemIcon: "figure.walk.arrival", label: L10n.entry, value: dive.entryType)
            }
            
            if !dive.buddyNames.isEmpty {
                SectionTitle(title: L10n.buddies)
                FlowLayout(spacing: 8) {
                    ForEach(dive.buddyList, id: \.self) { buddy in BuddyChip(name: buddy) }
                }
            }
            
            // Signatures
            SectionTitle(title: L10n.signatures)
            if (dive.signatures ?? []).isEmpty {
                Button {
                    showingSignatureCapture = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "hand.draw.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.appEmphasis)
                        Text(L10n.currentLanguage == "de" ? "Buddy jetzt signieren lassen" : "Have your buddy sign now")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.appEmphasis.opacity(0.08)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.appEmphasis.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4]))
                    )
                }
                .buttonStyle(.plain)
            } else {
                ForEach(dive.signatures ?? []) { sig in
                    SignatureCard(signature: sig)
                }
                // Add-another button
                Button {
                    showingSignatureCapture = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.appAccent.opacity(0.7))
                        Text(L10n.currentLanguage == "de" ? "Weitere Unterschrift hinzufügen" : "Add another signature")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.appAccent.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.appAccent.opacity(0.06)))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appAccent.opacity(0.15), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Journal
    private var journalContent: some View {
        VStack(spacing: 16) {
            // Rating
            if dive.rating > 0 {
                HStack(spacing: 4) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= dive.rating ? "star.fill" : "star")
                            .font(.system(size: 20))
                            .foregroundStyle(star <= dive.rating ? AnyShapeStyle(Color.appEmphasis) : AnyShapeStyle(.quaternary))
                    }
                }
                .frame(maxWidth: .infinity)
            }
            
            // Photos
            if !dive.photoFilenames.isEmpty {
                SectionTitle(title: L10n.photosLabel)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(dive.photoFilenames.enumerated()), id: \.element) { idx, filename in
                            Button { viewerStartIndex = idx } label: {
                                DivePhotoThumbnail(filename: filename, width: 220, height: 165)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
            
            // Notes
            if !dive.notes.isEmpty {
                SectionTitle(title: L10n.notesLabel)
                Text(dive.notes)
                    .font(.system(size: 15)).foregroundStyle(.secondary)
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.surfaceCard))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.hairline, lineWidth: 1))
            }
            
            // Marine life
            if !dive.marineLife.isEmpty {
                SectionTitle(title: L10n.marineLifeLabel)
                FlowLayout(spacing: 6) {
                    ForEach(dive.marineLife, id: \.self) { species in MarineLifeChip(species: species) }
                }
            }
            
            if dive.notes.isEmpty && dive.marineLife.isEmpty && dive.photoFilenames.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "text.book.closed").font(.system(size: 40)).foregroundStyle(.quaternary)
                    Text(L10n.currentLanguage == "de" ? "Noch kein Journal-Eintrag" : "No journal entry yet")
                        .font(.system(size: 14)).foregroundStyle(.tertiary)
                    Text(L10n.currentLanguage == "de" ? "Bearbeite diesen TG um Notizen und Fotos hinzuzufügen" : "Edit this dive to add notes and photos")
                        .font(.system(size: 12)).foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 40)
            }
        }
    }
    
    // MARK: - Profile (Depth)
    private var profileContent: some View {
        VStack(spacing: 12) {
            SectionTitle(title: L10n.currentLanguage == "de" ? "Tiefenprofil" : "Depth Profile")
            if !dive.depthProfile.isEmpty {
                DepthProfileChart(data: dive.depthProfile, maxDepth: dive.maxDepth, height: 200)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.surfaceCard))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.hairline, lineWidth: 1))
            }
            
            SectionTitle(title: L10n.currentLanguage == "de" ? "Flaschendruck" : "Tank Pressure")
            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("\(dive.tankStartBar)").font(.system(size: 24, weight: .black)).foregroundStyle(Color.appAccent)
                    Text("START BAR").font(.system(size: 9, weight: .semibold)).foregroundStyle(.tertiary).tracking(1)
                }.frame(maxWidth: .infinity)
                VStack(spacing: 4) {
                    Text("\(dive.tankEndBar)").font(.system(size: 24, weight: .black)).foregroundStyle(Color.appEmphasis)
                    Text("END BAR").font(.system(size: 9, weight: .semibold)).foregroundStyle(.tertiary).tracking(1)
                }.frame(maxWidth: .infinity)
                VStack(spacing: 4) {
                    Text("\(dive.tankUsed)").font(.system(size: 24, weight: .black)).foregroundStyle(.primary)
                    Text("USED").font(.system(size: 9, weight: .semibold)).foregroundStyle(.tertiary).tracking(1)
                }.frame(maxWidth: .infinity)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.surfaceCard))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.hairline, lineWidth: 1))
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(label: "SAC Rate", value: String(format: "%.1f", dive.sacRate), unit: "l/min", accent: true)
                StatCard(label: "Bar/min", value: String(format: "%.1f", dive.barPerMinute), unit: "bar/min")
            }
        }
    }
    
    // MARK: - Stats (Deco/Physio)
    private var statsContent: some View {
        VStack(spacing: 12) {
            if !dive.algorithm.isEmpty {
                SectionTitle(title: L10n.currentLanguage == "de" ? "Dekompression" : "Decompression")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatCard(label: L10n.currentLanguage == "de" ? "Algorithmus" : "Algorithm", value: dive.algorithm.components(separatedBy: " ").last ?? "--")
                    StatCard(label: "GF", value: dive.gradientFactors)
                    StatCard(label: "N₂ Start", value: "\(dive.n2LoadStart)", unit: "%")
                    StatCard(label: "N₂ End", value: "\(dive.n2LoadEnd)", unit: "%", accent: true)
                    StatCard(label: "CNS Start", value: "\(dive.cnsStart)", unit: "%")
                    StatCard(label: "CNS End", value: "\(dive.cnsEnd)", unit: "%")
                }
            }
            
            if dive.hrAvg > 0 {
                SectionTitle(title: L10n.currentLanguage == "de" ? "Physiologie" : "Physiology")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    StatCard(label: "Ø HR", value: "\(dive.hrAvg)", unit: "bpm", accent: true)
                    StatCard(label: "Max HR", value: "\(dive.hrMax)", unit: "bpm")
                    StatCard(label: L10n.currentLanguage == "de" ? "Kalorien" : "Calories", value: "\(dive.calories)", unit: "kcal")
                }
            }
            
            if !dive.computerModel.isEmpty {
                SectionTitle(title: "Computer")
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dive.computerModel).font(.system(size: 15, weight: .semibold)).foregroundStyle(.primary)
                        Text("\(dive.algorithm) • GF \(dive.gradientFactors)")
                            .font(.system(size: 13)).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.surfaceCard))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.hairline, lineWidth: 1))
            }
        }
    }
    
    // MARK: - Gear
    private var gearContent: some View {
        VStack(spacing: 12) {
            SectionTitle(title: L10n.currentLanguage == "de" ? "Kälteschutz" : "Exposure")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                InfoChip(systemIcon: "figure.water.fitness", label: L10n.suitLabel, value: dive.suit.replacingOccurrences(of: "_", with: " "))
                InfoChip(systemIcon: "scalemass.fill", label: L10n.weightLabel, value: "\(String(format: "%.0f", dive.weightKg)) kg (\(dive.weightFeel))")
            }
            
            SectionTitle(title: L10n.currentLanguage == "de" ? "Flasche & Gas" : "Cylinder & Gas")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                InfoChip(systemIcon: "cylinder.fill", label: L10n.cylinderLabel, value: "\(String(format: "%.1f", dive.cylinderSizeLiters))L \(dive.cylinderType)")
                InfoChip(systemIcon: "aqi.medium", label: L10n.gasLabel, value: dive.gas.uppercased())
                InfoChip(systemIcon: "gauge.with.dots.needle.33percent", label: L10n.tankStart, value: "\(dive.tankStartBar) bar")
                InfoChip(systemIcon: "gauge.with.dots.needle.bottom.50percent", label: L10n.tankEnd, value: "\(dive.tankEndBar) bar")
            }
            
            if !dive.diveCenterName.isEmpty {
                SectionTitle(title: L10n.diveCenterLabel)
                HStack {
                    Image(systemName: "building.2.fill").foregroundStyle(.secondary)
                    Text(dive.diveCenterName).font(.system(size: 15, weight: .semibold)).foregroundStyle(.primary)
                    Spacer()
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.surfaceCard))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.hairline, lineWidth: 1))
            }
        }
    }
}
