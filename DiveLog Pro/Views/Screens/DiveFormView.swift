import SwiftUI
import SwiftData
import CoreLocation

enum DiveFormMode { case new; case edit(Dive) }

struct DiveFormView: View {
    let mode: DiveFormMode

    // Optional pre-fill from QuickLogView. When prefillStudents is non-empty
    // the form opens in course-training mode, students are pre-selected, and
    // courseSlot defaults to the most-conservative "next module" across them.
    var prefillStudents: [Student] = []
    var prefillCourseType: String? = nil
    var prefillCourseSlot: String? = nil

    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Environment(\.atollBridge) private var atollBridge
    @Query(sort: \Dive.number, order: .reverse) private var existingDives: [Dive]
    @Query private var profiles: [DiverProfile]
    @State private var step = 0
    
    // ─── Form State ──────────────────────
    @State private var diveDate: Date = Date()
    @State private var siteName = ""
    @State private var siteLocation = ""
    @State private var diveType = "fun"
    @State private var maxDepth = ""
    @State private var bottomTime = ""
    @State private var totalTime = ""
    @State private var entryType = "shore"
    @State private var weather = "sunny"
    @State private var airTemp = ""
    @State private var waterTempSurface = ""
    @State private var waterTempBottom = ""
    @State private var visibility = ""
    @State private var current = "none"
    @State private var waves = "calm"

    // GPS & Weather
    @State private var latitude: Double? = nil
    @State private var longitude: Double? = nil
    @State private var isLoadingWeather = false
    @State private var isCapturingLocation = false
    @State private var weatherLoadError: String? = nil
    @State private var showPermissionHint = false
    @StateObject private var locationManager = LocationManager()

    @State private var suit = "shorty"
    @State private var weightKg = "2"
    @State private var weightFeel = "good"
    @State private var cylinderType = "aluminum"
    @State private var cylinderSize = "12"
    @State private var gas = "air"
    @State private var tankStart = "200"
    @State private var tankEnd = ""
    @State private var diveCenterName = ""
    
    @State private var feeling = "good"
    @State private var rating = 0
    @State private var isHighlight = false
    @State private var buddyNames = ""
    @State private var notes = ""
    @State private var marineLife: [String] = []
    @State private var marineInput = ""
    @State private var photoFilenames: [String] = []
    @State private var importedPhotosOnThisSession: [String] = []

    // Course training fields
    @State private var isCourseTraining = false
    @State private var courseType = "OWD"
    @State private var courseSlot = "OW1"
    @State private var students: [Student] = []

    private let suggestions = ["Sea Turtle", "Clownfish", "Manta Ray", "Whale Shark", "Nudibranch",
        "Moray Eel", "Barracuda", "Lionfish", "Octopus", "Seahorse", "Reef Shark",
        "Eagle Ray", "Frogfish", "Cuttlefish", "Giant Clam", "Dolphin"]
    
    private var isEditing: Bool { if case .edit = mode { return true }; return false }
    private var stepTitles: [String] { [L10n.stepBasics, L10n.stepEquipment, L10n.stepJournal] }
    
    var body: some View {
        NavigationStack {
            ZStack {
                HeroBackground()

                VStack(spacing: 0) {
                    // Step dots
                    HStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { i in
                            Capsule().fill(i <= step ? Color.appAccent : Color.hairline)
                                .frame(height: 3).onTapGesture { step = i }
                        }
                    }
                    .padding(.horizontal, DSSpacing.xl).padding(.top, DSSpacing.s).padding(.bottom, DSSpacing.m + 2)

                    Text(stepTitles[step].uppercased())
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.appAccent)
                        .tracking(1.5)
                        .padding(.bottom, DSSpacing.m)

                    ScrollView {
                        VStack(spacing: DSSpacing.m + 2) {
                            switch step {
                            case 0: stepBasics
                            case 1: stepEquipment
                            case 2: stepJournal
                            default: EmptyView()
                            }
                        }
                        .padding(.horizontal, DSSpacing.xl).padding(.bottom, 100)
                    }
                    .scrollContentBackground(.hidden)

                    // Buttons
                    HStack(spacing: DSSpacing.m) {
                        if step > 0 {
                            Button(L10n.back) { withAnimation { step -= 1 } }
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.appAccent)
                                .frame(maxWidth: .infinity).frame(height: 50)
                                .background(RoundedRectangle(cornerRadius: DSRadius.m + 2).stroke(Color.hairline, lineWidth: 1))
                        }
                        Button(step == 2 ? (isEditing ? L10n.updateDive : L10n.saveDive) : L10n.next) {
                            if step < 2 { withAnimation { step += 1 } } else { save() }
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color(uiColor: .systemBackground))
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(RoundedRectangle(cornerRadius: DSRadius.m + 2).fill(
                            step == 2 ? LinearGradient(colors: [.appEmphasis, .appAccent], startPoint: .topLeading, endPoint: .bottomTrailing)
                                      : LinearGradient(colors: [.appAccent, .appAccent], startPoint: .leading, endPoint: .trailing)
                        ))
                    }
                    .padding(.horizontal, DSSpacing.xl).padding(.bottom, DSSpacing.l)
                }
            }
            .navigationTitle(isEditing ? L10n.editDive : L10n.quickLog)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        discardUnsavedPhotos()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(.ultraThinMaterial))
                            .overlay(Circle().stroke(Color.hairline, lineWidth: 0.5))
                    }
                }
            }
            .onAppear { loadDefaults() }
        }
    }
    
    // ═══════════════════════════════════════
    // MARK: - Step 1: Basics
    // ═══════════════════════════════════════
    
    private var stepBasics: some View {
        VStack(spacing: 14) {
            FormField(label: L10n.diveSite, text: $siteName, placeholder: "Horn")
            FormField(label: L10n.location, text: $siteLocation, placeholder: "Richterswil")

            // Date & Time
            VStack(alignment: .leading, spacing: 8) {
                Text((L10n.currentLanguage == "de" ? "Datum & Uhrzeit" : "Date & time").uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(1.2)
                DatePicker(
                    "",
                    selection: $diveDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DSSpacing.m)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: DSRadius.m).fill(Color.surfaceCard))
                .overlay(RoundedRectangle(cornerRadius: DSRadius.m).stroke(Color.hairline, lineWidth: 0.5))
            }

            // GPS & Auto-Weather
            gpsWeatherBlock

            // Dive Type
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.diveType.uppercased()).font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary).tracking(1.2)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(DiveTypeOption.all) { opt in
                            Button { diveType = opt.id } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: opt.icon).font(.system(size: 11))
                                    Text(opt.label).font(.system(size: 12, weight: diveType == opt.id ? .bold : .medium))
                                }
                                .foregroundStyle(diveType == opt.id ? Color.appAccent : .secondary)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: DSRadius.s).fill(diveType == opt.id ? Color.appAccent.opacity(0.12) : Color.surfaceCard))
                                .overlay(RoundedRectangle(cornerRadius: DSRadius.s).stroke(diveType == opt.id ? Color.appAccent.opacity(0.25) : Color.hairline.opacity(0.5), lineWidth: 1))
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }

            // Course & Students (Pro only)
            if StoreManager.shared.isPro {
            VStack(alignment: .leading, spacing: 8) {
                Text((L10n.currentLanguage == "de" ? "Kurs & Schüler" : "Course & Students").uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(1.2)
                Toggle(L10n.currentLanguage == "de" ? "Kurs-Tauchgang" : "Course dive",
                       isOn: $isCourseTraining)
                if isCourseTraining {
                    Picker(L10n.currentLanguage == "de" ? "Kurs" : "Course", selection: $courseType) {
                        Text("OWD").tag("OWD")
                        Text("AOWD").tag("AOWD")
                        Text("Dry Suit").tag("DRYSUIT")
                        Text("Rescue").tag("RESCUE")
                    }
                    Picker(L10n.currentLanguage == "de" ? "Modul" : "Module", selection: $courseSlot) {
                        ForEach(PADIStandards.shared.slots(for: courseType)
                                    .filter { $0.type == .ocean }, id: \.code) { slot in
                            Text(slot.title).tag(slot.code)
                        }
                    }
                    StudentPicker(selected: $students)
                    if !students.isEmpty {
                        ForEach(students) { student in
                            PreDivePreviewCard(student: student, slotCode: courseSlot, courseType: courseType)
                        }
                    }
                }
            }
            } // end if isPro

            HStack(spacing: 12) {
                FormField(label: L10n.maxDepth + " (m)", text: $maxDepth, placeholder: "12", keyboard: .decimalPad)
                FormField(label: L10n.bottomTime + " (min)", text: $bottomTime, placeholder: "45", keyboard: .numberPad)
            }
            HStack(spacing: 12) {
                FormField(label: L10n.totalTime + " (min)", text: $totalTime, placeholder: "48", keyboard: .numberPad)
                VStack {} // spacer
            }
            
            SegmentPicker(label: L10n.entry, options: [("boat", "🚤 Boat"), ("shore", "🏖 Shore")], selected: $entryType)
            
            HStack(spacing: 12) {
                FormField(label: L10n.waterTempSurface + " (°C)", text: $waterTempSurface, placeholder: "18", keyboard: .decimalPad)
                FormField(label: L10n.waterTempBottom + " (°C)", text: $waterTempBottom, placeholder: "12", keyboard: .decimalPad)
            }
            HStack(spacing: 12) {
                FormField(label: L10n.airTempLabel + " (°C)", text: $airTemp, placeholder: "22", keyboard: .decimalPad)
                FormField(label: L10n.visibilityLabel + " (m)", text: $visibility, placeholder: "15", keyboard: .numberPad)
            }
            
            SegmentPicker(label: L10n.currentLabel, options: [("none", L10n.none), ("light", L10n.light), ("moderate", L10n.moderate), ("strong", L10n.strong)], selected: $current)
            SegmentPicker(label: L10n.wavesLabel, options: [("calm", L10n.calm), ("slight", L10n.slight), ("moderate", L10n.moderate), ("rough", L10n.rough)], selected: $waves)
            SegmentPicker(label: L10n.weatherLabel, options: [("sunny", "☀"), ("partly_cloudy", "⛅"), ("cloudy", "☁"), ("rainy", "🌧")], selected: $weather)
        }
    }
    
    // ═══════════════════════════════════════
    // MARK: - Step 2: Equipment
    // ═══════════════════════════════════════
    
    private var stepEquipment: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                FormField(label: L10n.tankStart + " (bar)", text: $tankStart, placeholder: "200", keyboard: .numberPad)
                FormField(label: L10n.tankEnd + " (bar)", text: $tankEnd, placeholder: "50", keyboard: .numberPad)
            }
            HStack(spacing: 12) {
                FormField(label: L10n.cylinderLabel + " (L)", text: $cylinderSize, placeholder: "12", keyboard: .decimalPad)
                SegmentPicker(label: L10n.currentLanguage == "de" ? "Typ" : "Type", options: [("aluminum", "Alu"), ("steel", "Steel")], selected: $cylinderType)
            }
            SegmentPicker(label: L10n.gasLabel, options: [("air", "Air"), ("eanx32", "EANx32"), ("eanx36", "EANx36"), ("eanx40", "EANx40")], selected: $gas)
            
            SegmentPicker(label: L10n.suitLabel, options: [("none", "None"), ("shorty", "Shorty"), ("3mm", "3mm"), ("5mm", "5mm")], selected: $suit)
            SegmentPicker(label: " ", options: [("7mm", "7mm"), ("semi_dry", "Semi-dry"), ("drysuit", "Drysuit")], selected: $suit)
            
            HStack(spacing: 12) {
                FormField(label: L10n.weightLabel + " (kg)", text: $weightKg, placeholder: "2", keyboard: .decimalPad)
                SegmentPicker(label: L10n.currentLanguage == "de" ? "Trimm" : "Trim", options: [("light", "⬆"), ("good", "✓"), ("heavy", "⬇")], selected: $weightFeel)
            }
            
            FormField(label: L10n.diveCenterLabel, text: $diveCenterName, placeholder: "e.g. Amun Ini")
        }
    }
    
    // ═══════════════════════════════════════
    // MARK: - Step 3: Journal
    // ═══════════════════════════════════════
    
    private var stepJournal: some View {
        VStack(spacing: 14) {
            // Feeling
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.feeling.uppercased()).font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary).tracking(1.2)
                HStack(spacing: 10) {
                    ForEach([("amazing", "🤩"), ("good", "😊"), ("average", "😐"), ("poor", "😕")], id: \.0) { val, emoji in
                        Button { feeling = val } label: {
                            Text(emoji).font(.system(size: 28))
                                .frame(width: 56, height: 56)
                                .background(Circle().fill(feeling == val ? Color.appAccent.opacity(0.12) : Color.surfaceCard))
                                .overlay(Circle().stroke(feeling == val ? Color.appAccent.opacity(0.25) : Color.hairline.opacity(0.5), lineWidth: 2))
                                .scaleEffect(feeling == val ? 1.1 : 1.0)
                                .animation(.easeInOut(duration: 0.2), value: feeling)
                        }.buttonStyle(.plain)
                    }
                }
            }
            
            // Rating
            VStack(alignment: .leading, spacing: 8) {
                Text((L10n.currentLanguage == "de" ? "Bewertung" : "Rating").uppercased())
                    .font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary).tracking(1.2)
                StarRating(rating: $rating)
            }
            
            // Highlight
            Toggle(isOn: $isHighlight) {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill").foregroundStyle(isHighlight ? AnyShapeStyle(Color.appEmphasis) : AnyShapeStyle(.tertiary))
                    Text(L10n.currentLanguage == "de" ? "Highlight-Tauchgang" : "Highlight Dive")
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(.primary)
                }
            }
            .tint(.appEmphasis)
            
            FormField(label: L10n.buddyLabel, text: $buddyNames, placeholder: "e.g. Lance Lagria, Jeryll")
            
            // Marine Life
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.marineLifeLabel.uppercased()).font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary).tracking(1.2)
                if !marineLife.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(marineLife, id: \.self) { species in
                            HStack(spacing: 4) {
                                Text("🐠 \(species)").font(.system(size: 12, weight: .medium))
                                Button { marineLife.removeAll { $0 == species } } label: {
                                    Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                                }
                            }
                            .foregroundStyle(Color.appAccent)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Capsule().fill(Color.appAccent.opacity(0.10)))
                            .overlay(Capsule().stroke(Color.appAccent.opacity(0.2), lineWidth: 1))
                        }
                    }
                }
                TextField(L10n.currentLanguage == "de" ? "Art eingeben..." : "Type species...", text: $marineInput)
                    .font(.system(size: 14)).foregroundStyle(.primary)
                    .padding(DSSpacing.m)
                    .background(RoundedRectangle(cornerRadius: DSRadius.m).fill(Color.surfaceCard))
                    .overlay(RoundedRectangle(cornerRadius: DSRadius.m).stroke(Color.hairline, lineWidth: 0.5))
                    .onSubmit { addMarineLife(marineInput) }
                
                FlowLayout(spacing: 6) {
                    ForEach(suggestions.filter { !marineLife.contains($0) }.prefix(8), id: \.self) { s in
                        Button { addMarineLife(s) } label: {
                            Text(s).font(.system(size: 11)).foregroundStyle(.tertiary)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Capsule().stroke(Color.hairline, style: StrokeStyle(lineWidth: 1, dash: [4])))
                        }.buttonStyle(.plain)
                    }
                }
            }
            
            // Photos — PhotosPicker integration
            PhotoPickerSection(filenames: $photoFilenames, maxPhotos: 20)
                .onChange(of: photoFilenames) { oldValue, newValue in
                    // Track newly imported filenames so we can roll them back
                    // if the user cancels instead of saving.
                    let added = Set(newValue).subtracting(oldValue)
                    for name in added { importedPhotosOnThisSession.append(name) }
                }
            
            // Notes
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.notesLabel.uppercased()).font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary).tracking(1.2)
                TextEditor(text: $notes)
                    .font(.system(size: 14)).foregroundStyle(.primary).scrollContentBackground(.hidden)
                    .frame(minHeight: 100).padding(DSSpacing.m)
                    .background(RoundedRectangle(cornerRadius: DSRadius.m).fill(Color.surfaceCard))
                    .overlay(RoundedRectangle(cornerRadius: DSRadius.m).stroke(Color.hairline, lineWidth: 0.5))
            }
        }
    }
    
    // ═══════════════════════════════════════
    // MARK: - GPS & Weather Block
    // ═══════════════════════════════════════

    private var gpsWeatherBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.gpsLabel.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(1.2)
                Spacer()
                if isLoadingWeather {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.7)
                        Text(L10n.loadingWeather)
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            if let lat = latitude, let lon = longitude {
                HStack {
                    Image(systemName: "location.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.appAccent)
                    Text(String(format: "%.4f°, %.4f°", lat, lon))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.primary)
                    Spacer()
                    Button {
                        latitude = nil
                        longitude = nil
                        weatherLoadError = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: DSRadius.m).fill(Color.appAccent.opacity(0.10)))
                .overlay(RoundedRectangle(cornerRadius: DSRadius.m).stroke(Color.appAccent.opacity(0.2), lineWidth: 1))
            } else {
                Button {
                    Task { await captureLocation() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "location.circle")
                            .font(.system(size: 13))
                        Text(L10n.currentLocation)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(isCapturingLocation ? Color.textDim : Color.appAccent)
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: DSRadius.m).fill(Color.surfaceCard))
                    .overlay(RoundedRectangle(cornerRadius: DSRadius.m).stroke(Color.hairline, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(isCapturingLocation)
            }

            if let err = weatherLoadError {
                VStack(alignment: .leading, spacing: 4) {
                    Text(err)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.appEmphasis.opacity(0.9))
                    if showPermissionHint, let url = URL(string: UIApplication.openSettingsURLString) {
                        Button { UIApplication.shared.open(url) } label: {
                            Text(L10n.currentLanguage == "de" ? "In Einstellungen öffnen" : "Open in Settings")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.appAccent)
                        }
                    }
                }
            }
        }
    }

    private func captureLocation() async {
        guard !isCapturingLocation else { return }  // re-entrancy guard
        isCapturingLocation = true
        weatherLoadError = nil
        showPermissionHint = false
        defer { isCapturingLocation = false }

        do {
            let loc = try await locationManager.requestOneShot()
            latitude = loc.coordinate.latitude
            longitude = loc.coordinate.longitude
            await loadWeather()
        } catch LocationManager.LocationError.permissionDenied {
            weatherLoadError = LocationManager.LocationError.permissionDenied.localizedDescription
            showPermissionHint = true
        } catch {
            weatherLoadError = error.localizedDescription
        }
    }

    private func loadWeather() async {
        guard let lat = latitude, let lon = longitude else { return }
        let diveDate: Date = {
            if case .edit(let d) = mode { return d.date }
            return Date()
        }()

        isLoadingWeather = true
        defer { isLoadingWeather = false }

        do {
            let snap = try await DiveWeatherService.shared.fetch(
                lat: lat, lon: lon, date: diveDate
            )
            // Only overwrite the weather field if it's still the form default.
            if weather == "sunny" || weather.isEmpty {
                weather = snap.condition
            }
            // Only overwrite air temp if empty — respects user input.
            if airTemp.isEmpty {
                airTemp = String(format: "%.0f", snap.airTempC)
            }
        } catch {
            weatherLoadError = error.localizedDescription
        }
    }

    // ═══════════════════════════════════════
    // MARK: - Helpers
    // ═══════════════════════════════════════

    private func addMarineLife(_ name: String) {
        let t = name.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, !marineLife.contains(t) else { return }
        marineLife.append(t); marineInput = ""
    }
    
    private func loadDefaults() {
        if case .edit(let d) = mode {
            diveDate = d.date
            siteName = d.siteName; siteLocation = d.siteLocation; diveType = d.diveType
            if d.latitude != 0 || d.longitude != 0 {
                latitude = d.latitude
                longitude = d.longitude
            }
            maxDepth = String(d.maxDepth); bottomTime = String(d.bottomTime); totalTime = String(d.totalTime)
            entryType = d.entryType; weather = d.weather
            airTemp = String(d.airTemp); waterTempSurface = String(d.waterTempSurface); waterTempBottom = String(d.waterTempBottom)
            visibility = String(d.visibility); current = d.current; waves = d.waves
            suit = d.suit; weightKg = String(d.weightKg); weightFeel = d.weightFeel
            cylinderType = d.cylinderType; cylinderSize = String(d.cylinderSizeLiters); gas = d.gas
            tankStart = String(d.tankStartBar); tankEnd = String(d.tankEndBar); diveCenterName = d.diveCenterName
            feeling = d.feeling; rating = d.rating; isHighlight = d.isHighlight
            buddyNames = d.buddyNames; notes = d.notes; marineLife = d.marineLife
            photoFilenames = d.photoFilenames
            isCourseTraining = d.courseType != nil
            courseType = d.courseType ?? "OWD"
            courseSlot = d.courseSlot ?? "OW1"
            students = d.students ?? []
        } else if let last = existingDives.first {
            // Smart Defaults from last dive
            suit = last.suit; weightKg = String(last.weightKg); weightFeel = last.weightFeel
            cylinderType = last.cylinderType; cylinderSize = String(last.cylinderSizeLiters); gas = last.gas
            tankStart = String(last.tankStartBar); diveCenterName = last.diveCenterName
        }

        // Apply QuickLog pre-fill (only in .new mode — edit always wins).
        if case .new = mode, !prefillStudents.isEmpty {
            isCourseTraining = true
            students = prefillStudents
            if let t = prefillCourseType { courseType = t }
            if let slot = prefillCourseSlot {
                courseSlot = slot
            } else {
                courseSlot = suggestedNextSlot(forStudents: prefillStudents, courseType: courseType)
            }
        }
    }

    /// Most-conservative "next module" across a group of students for an
    /// open-water course. For each student: find the highest ocean slot with
    /// any mastered skill, the next slot is their candidate. Group pick = min.
    private func suggestedNextSlot(forStudents students: [Student], courseType: String) -> String {
        let slots = PADIStandards.shared.slots(for: courseType).filter { $0.type == .ocean }
        guard !slots.isEmpty else { return "OW1" }

        var minIndex = slots.count - 1
        for student in students {
            var lastMasteredIdx = -1
            for (idx, slot) in slots.enumerated() {
                let anyMastered = slot.skills.contains {
                    student.currentStatus(for: $0.code) == .mastered
                }
                if anyMastered { lastMasteredIdx = idx }
            }
            let next = min(lastMasteredIdx + 1, slots.count - 1)
            minIndex = min(minIndex, next)
        }
        return slots[max(0, minIndex)].code
    }

    /// Called when the user taps the close button without saving. Any photos
    /// imported during this session that aren't already attached to a saved
    /// dive need to be cleaned up so they don't leak into the documents dir.
    private func discardUnsavedPhotos() {
        guard case .new = mode else {
            // In edit mode: remove any newly imported files that the user
            // didn't keep in the final list (they may have hit "x" on them).
            let attachedSet = Set(photoFilenames)
            let orphaned = importedPhotosOnThisSession.filter { !attachedSet.contains($0) }
            orphaned.forEach { PhotoStore.delete(filename: $0) }
            return
        }
        // New mode + dismissed without saving → delete everything imported.
        importedPhotosOnThisSession.forEach { PhotoStore.delete(filename: $0) }
    }
    
    /// Refresh the App Group snapshot for Atoll Hub. Fires from
    /// `save()` after in-memory mutations land on `Dive` but before
    /// SwiftData drains its context to disk + CloudKit. That's
    /// intentional: the publisher fetches from `mainContext`, so it sees
    /// the just-edited values; persistence catches up asynchronously.
    private func republishToAtollBridge() {
        guard let bridge = atollBridge else { return }
        let container = ctx.container
        Task { @MainActor in
            await DiveLogBridgePublisher(container: container, bridge: bridge).publish()
        }
    }

    private func save() {
        let md = Double(maxDepth) ?? 15
        let bt = Int(bottomTime) ?? 40
        let tt = Int(totalTime) ?? bt + 3
        let ts = Int(tankStart) ?? 200; let te = Int(tankEnd) ?? 50
        
        if case .edit(let d) = mode {
            // Clean up photos the user removed during editing
            let before = Set(d.photoFilenames)
            let after = Set(photoFilenames)
            for removed in before.subtracting(after) {
                PhotoStore.delete(filename: removed)
            }

            // Detect whether depth or duration changed meaningfully — only
            // regenerate the simulated profile when they did. Preserves real
            // computer-sourced profiles on cosmetic edits.
            let depthChanged = abs(d.maxDepth - md) > 0.5
            let timeChanged  = abs(d.totalTime - tt) > 1
            let profileMissing = d.depthProfile.isEmpty

            d.date = diveDate
            d.siteName = siteName; d.siteLocation = siteLocation; d.diveType = diveType
            if isCourseTraining {
                d.courseType = courseType
                d.courseSlot = courseSlot
                d.students = students
            } else {
                d.courseType = nil
                d.courseSlot = nil
                d.students = []
            }
            if let lat = latitude { d.latitude = lat }
            if let lon = longitude { d.longitude = lon }
            d.maxDepth = md; d.avgDepth = md * 0.7; d.bottomTime = bt; d.totalTime = tt
            d.entryType = entryType; d.weather = weather
            d.airTemp = Double(airTemp) ?? 30
            d.waterTempSurface = Double(waterTempSurface) ?? 28; d.waterTempBottom = Double(waterTempBottom) ?? 26
            d.visibility = Int(visibility) ?? 0; d.current = current; d.waves = waves
            d.suit = suit; d.weightKg = Double(weightKg) ?? 2; d.weightFeel = weightFeel
            d.cylinderType = cylinderType; d.cylinderSizeLiters = Double(cylinderSize) ?? 12; d.gas = gas
            d.tankStartBar = ts; d.tankEndBar = te; d.diveCenterName = diveCenterName
            d.feeling = feeling; d.rating = rating; d.isHighlight = isHighlight
            d.buddyNames = buddyNames; d.notes = notes; d.marineLife = marineLife
            d.photoFilenames = photoFilenames

            if profileMissing || depthChanged || timeChanged {
                d.depthProfile = SampleData.generateProfile(maxDepth: md, duration: tt)
            }
        } else {
            // Fallback for the very first dive uses the user's chosen starting
            // number (set in Profile → Logbook). After that, new dives always
            // increment from the current maximum dive.number regardless of
            // the profile setting, so "9001 → 9002 → 9003 …" works naturally.
            let startingNumber = profiles.first?.startingDiveNumber ?? 8758
            let num = (existingDives.first?.number ?? (startingNumber - 1)) + 1
            let dive = Dive(
                number: num, date: diveDate, diveType: diveType, siteName: siteName, siteLocation: siteLocation,
                latitude: latitude ?? 0, longitude: longitude ?? 0,
                diveCenterName: diveCenterName,
                maxDepth: md, avgDepth: md * 0.7, bottomTime: bt, totalTime: tt,
                entryType: entryType, weather: weather, airTemp: Double(airTemp) ?? 30,
                waterTempSurface: Double(waterTempSurface) ?? 28, waterTempBottom: Double(waterTempBottom) ?? 26,
                visibility: Int(visibility) ?? 0, current: current, waves: waves,
                suit: suit, weightKg: Double(weightKg) ?? 2, weightFeel: weightFeel,
                cylinderType: cylinderType, cylinderSizeLiters: Double(cylinderSize) ?? 12, gas: gas,
                tankStartBar: ts, tankEndBar: te,
                notes: notes, feeling: feeling, rating: rating, isHighlight: isHighlight,
                buddyNames: buddyNames, marineLife: marineLife,
                depthProfile: SampleData.generateProfile(maxDepth: md, duration: tt)
            )
            if isCourseTraining {
                dive.courseType = courseType
                dive.courseSlot = courseSlot
                dive.students = students
            }
            dive.photoFilenames = photoFilenames
            ctx.insert(dive)
        }
        // Saving succeeded — any imported photos are now attached to a dive
        // and shouldn't be cleaned up on dismiss.
        importedPhotosOnThisSession = []
        republishToAtollBridge()
        dismiss()
    }
}
