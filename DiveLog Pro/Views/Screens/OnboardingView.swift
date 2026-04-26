import SwiftUI
import SwiftData
import PhotosUI

// ═══════════════════════════════════════
// MARK: - Onboarding (Phase 6)
// ═══════════════════════════════════════

/// Five-screen first-run experience. Writes directly to the single
/// `DiverProfile` in the model (creates one if missing). Every screen
/// can be skipped via the top-right "Skip" button — whatever has been
/// entered up to that point is saved, then onboarding dismisses.
///
/// Screens:
///   0. Welcome                — brand moment + feature bullets
///   1. Preferences            — language + metric/imperial
///   2. Identity               — photo, name, PADI#, cert level
///   3. Smart Defaults         — suit, weight, cylinder, gas
///   4. Stamp                  — reuse StampGeneratorView from ProfileEditView
struct OnboardingView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [DiverProfile]

    @AppStorage("hasCompletedOnboarding") private var hasCompleted: Bool = false
    @AppStorage("appLanguage") private var appLanguage: String = "en"

    @State private var step: Int = 0
    private let totalSteps = 5

    // ── Step 1 (preferences)
    @State private var useMetric: Bool = true

    // ── Step 2 (identity)
    @State private var name: String = ""
    @State private var padiNumber: String = ""
    @State private var certLevel: String = "AOWD"
    @State private var email: String = ""
    @State private var profileImageData: Data?
    @State private var photoItem: PhotosPickerItem?

    // ── Step 3 (defaults)
    @State private var defaultSuit: String = "shorty"
    @State private var defaultWeight: Double = 2
    @State private var cylinderType: String = "aluminum"
    @State private var cylinderSize: Int = 12
    @State private var defaultGas: String = "air"

    // ── Step 4 (stamp)
    @State private var stampData: Data?
    @State private var showingStampGen: Bool = false

    private var isDE: Bool { appLanguage == "de" }

    var body: some View {
        ZStack {
            // Background — adaptive gradient matching the rest of the app
            LinearGradient(
                colors: [
                    Color.appAccent.opacity(0.15),
                    Color(uiColor: .systemBackground),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Color.appAccent.opacity(0.08), Color.clear],
                center: UnitPoint(x: 0.5, y: 0.15),
                startRadius: 40,
                endRadius: 400
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                ScrollView {
                    VStack(spacing: 20) {
                        stepContent
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 28)
                    .padding(.bottom, 20)
                }

                bottomBar
                    .padding(.horizontal, 24)
                    .padding(.bottom, 30)
            }
        }
        // Follows system appearance
        .sheet(isPresented: $showingStampGen) {
            StampGeneratorView(
                name: name.isEmpty ? (isDE ? "Taucher" : "Diver") : name,
                padiNumber: padiNumber,
                certLevel: certLevel,
                onSave: { data in
                    stampData = data
                    showingStampGen = false
                }
            )
        }
        .onAppear { loadFromExistingProfile() }
    }

    // ═══════════════════════════════════════
    // MARK: - Top / Bottom Bars

    private var topBar: some View {
        HStack {
            // Progress dots
            HStack(spacing: 8) {
                ForEach(0..<totalSteps, id: \.self) { i in
                    Capsule()
                        .fill(i == step ? Color.appAccent : Color.hairline)
                        .frame(width: i == step ? 24 : 8, height: 8)
                        .animation(.easeInOut(duration: 0.25), value: step)
                }
            }

            Spacer()

            if step > 0 {
                Button {
                    skipOnboarding()
                } label: {
                    Text(isDE ? "Überspringen" : "Skip")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            if step > 0 {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { step -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 54, height: 54)
                        .background(Circle().fill(Color.surfaceCard))
                        .overlay(Circle().stroke(Color.hairline, lineWidth: 1))
                }
            }

            Button {
                advance()
            } label: {
                HStack(spacing: 8) {
                    Text(primaryCTA)
                        .font(.system(size: 16, weight: .bold))
                    if step < totalSteps - 1 {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                    }
                }
                .foregroundStyle(Color(uiColor: .systemBackground))
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(RoundedRectangle(cornerRadius: DSRadius.l).fill(Color.appAccent))
            }
            .disabled(!canAdvance)
            .opacity(canAdvance ? 1 : 0.5)
        }
    }

    private var primaryCTA: String {
        switch step {
        case 0: return isDE ? "Los geht's" : "Let's go"
        case totalSteps - 1: return isDE ? "App starten" : "Start app"
        default: return isDE ? "Weiter" : "Continue"
        }
    }

    private var canAdvance: Bool {
        switch step {
        case 2: return !name.trimmingCharacters(in: .whitespaces).isEmpty
        default: return true
        }
    }

    // ═══════════════════════════════════════
    // MARK: - Step Router

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0: welcomeStep
        case 1: preferencesStep
        case 2: identityStep
        case 3: defaultsStep
        case 4: stampStep
        default: EmptyView()
        }
    }

    // ═══════════════════════════════════════
    // MARK: - Step 0: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 28) {
            Spacer().frame(height: 20)

            // Hero icon
            diveGlyph
                .frame(width: 120, height: 120)

            VStack(spacing: 10) {
                Text(isDE ? "Dein Tauchlogbuch.\nEndlich digital." : "Your dive log.\nFinally digital.")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)

                Text(isDE
                     ? "Von Course Directors für Taucher gemacht."
                     : "Built by Course Directors for divers.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 14) {
                featureBullet(icon: "wifi.slash",
                              title: isDE ? "Offline-first" : "Offline-first",
                              subtitle: isDE ? "Logge TGs auch auf dem Boot ohne Netz" : "Log dives on the boat without signal")
                featureBullet(icon: "signature",
                              title: isDE ? "Echte Unterschriften" : "Real signatures",
                              subtitle: isDE ? "Buddies signieren direkt am Gerät" : "Buddies sign right on the device")
                featureBullet(icon: "doc.richtext",
                              title: isDE ? "PADI-kompatibel" : "PADI-compatible",
                              subtitle: isDE ? "Export als PDF im gewohnten Layout" : "Export as PDF in the familiar layout")
            }
            .padding(.top, 8)

            Spacer()
        }
    }

    private func featureBullet(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.appAccent.opacity(0.12)).frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.appAccent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // ═══════════════════════════════════════
    // MARK: - Step 1: Preferences

    private var preferencesStep: some View {
        VStack(alignment: .leading, spacing: 26) {
            Spacer().frame(height: 10)

            stepHeader(
                title: isDE ? "Deine Einstellungen" : "Your Preferences",
                subtitle: isDE ? "Kannst du jederzeit ändern." : "You can change these anytime."
            )

            // Language
            VStack(alignment: .leading, spacing: 8) {
                Text((isDE ? "Sprache" : "Language").uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(1.5)
                Picker("", selection: $appLanguage) {
                    Text("English").tag("en")
                    Text("Deutsch").tag("de")
                }
                .pickerStyle(.segmented)
            }

            // Units
            VStack(alignment: .leading, spacing: 8) {
                Text((isDE ? "Einheiten" : "Units").uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(1.5)
                Picker("", selection: $useMetric) {
                    Text(isDE ? "Metrisch (m, °C, bar)" : "Metric (m, °C, bar)").tag(true)
                    Text(isDE ? "Imperial (ft, °F, psi)" : "Imperial (ft, °F, psi)").tag(false)
                }
                .pickerStyle(.segmented)
                Text(useMetric
                     ? (isDE ? "Tiefe in Metern, Temperatur in °C, Druck in bar." : "Depth in meters, temperature in °C, pressure in bar.")
                     : (isDE ? "Tiefe in Fuß, Temperatur in °F, Druck in psi." : "Depth in feet, temperature in °F, pressure in psi."))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }

            Spacer()
        }
    }

    // ═══════════════════════════════════════
    // MARK: - Step 2: Identity

    private var identityStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer().frame(height: 6)

            stepHeader(
                title: isDE ? "Wer taucht hier?" : "Who's diving?",
                subtitle: isDE ? "Name ist Pflicht, der Rest optional." : "Name required, rest is optional."
            )

            // Photo
            HStack {
                Spacer()
                PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                    if let data = profileImageData, let img = UIImage(data: data) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 110, height: 110)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.hairline, lineWidth: 2))
                    } else {
                        ZStack {
                            Circle()
                                .fill(Color.surfaceCard)
                                .frame(width: 110, height: 110)
                                .overlay(
                                    Circle().stroke(
                                        Color.hairline,
                                        style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                                    )
                                )
                            VStack(spacing: 6) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(Color.appAccent.opacity(0.7))
                                Text(isDE ? "Foto" : "Photo")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onChange(of: photoItem) { _, newItem in
                    Task { await loadPhoto(newItem) }
                }
                Spacer()
            }

            FormField(
                label: isDE ? "Name" : "Name",
                text: $name,
                placeholder: isDE ? "Vor- und Nachname" : "Full name"
            )

            FormField(
                label: isDE ? "PADI-Nummer (optional)" : "PADI Number (optional)",
                text: $padiNumber,
                placeholder: "e.g. 335680",
                keyboard: .numberPad
            )

            // Cert level
            VStack(alignment: .leading, spacing: 6) {
                Text((isDE ? "Zertifizierung" : "Certification").uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(1.2)
                Menu {
                    ForEach(certOptions, id: \.0) { opt in
                        Button(opt.1) { certLevel = opt.0 }
                    }
                } label: {
                    HStack {
                        Text(certOptions.first { $0.0 == certLevel }?.1 ?? certLevel)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .font(.system(size: 15))
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.surfaceCard))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.hairline, lineWidth: 1))
                }
            }

            FormField(
                label: isDE ? "E-Mail (optional)" : "Email (optional)",
                text: $email,
                placeholder: "name@example.com",
                keyboard: .emailAddress
            )

            Spacer(minLength: 0)
        }
    }

    private var certOptions: [(String, String)] {
        [
            ("OWD",       "PADI Open Water Diver"),
            ("AOWD",      "PADI Advanced Open Water"),
            ("Rescue",    isDE ? "PADI Rescue Diver" : "PADI Rescue Diver"),
            ("DM",        isDE ? "PADI Divemaster" : "PADI Divemaster"),
            ("OWSI",      "PADI OWSI"),
            ("MSDT",      "PADI MSDT"),
            ("IDC Staff", "PADI IDC Staff Instructor"),
            ("CD",        "PADI Course Director"),
        ]
    }

    // ═══════════════════════════════════════
    // MARK: - Step 3: Smart Defaults

    private var defaultsStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer().frame(height: 6)

            stepHeader(
                title: isDE ? "Smart Defaults" : "Smart Defaults",
                subtitle: isDE ? "Damit das Loggen schneller geht." : "To make logging faster."
            )

            // Suit
            VStack(alignment: .leading, spacing: 8) {
                labeledCaps(isDE ? "Anzug" : "Suit")
                Picker("", selection: $defaultSuit) {
                    Text("Shorty").tag("shorty")
                    Text("3 mm").tag("3mm")
                    Text("5 mm").tag("5mm")
                    Text("7 mm").tag("7mm")
                    Text(isDE ? "Dry" : "Dry").tag("drysuit")
                }
                .pickerStyle(.segmented)
            }

            // Weight
            VStack(alignment: .leading, spacing: 8) {
                labeledCaps(isDE ? "Bleigewicht (kg)" : "Weight (kg)")
                HStack(spacing: 12) {
                    Button {
                        defaultWeight = max(0, defaultWeight - 0.5)
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.primary)
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(Color.surfaceCard))
                    }
                    Text(String(format: "%.1f kg", defaultWeight))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.appAccent)
                        .frame(maxWidth: .infinity)
                    Button {
                        defaultWeight = min(20, defaultWeight + 0.5)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.primary)
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(Color.surfaceCard))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.surfaceCard))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.hairline, lineWidth: 1))
            }

            // Cylinder
            VStack(alignment: .leading, spacing: 8) {
                labeledCaps(isDE ? "Standard-Flasche" : "Default Cylinder")
                HStack(spacing: 10) {
                    Picker("", selection: $cylinderType) {
                        Text(isDE ? "Alu" : "Alu").tag("aluminum")
                        Text(isDE ? "Stahl" : "Steel").tag("steel")
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: .infinity)

                    Menu {
                        ForEach([10, 12, 15], id: \.self) { v in
                            Button("\(v) L") { cylinderSize = v }
                        }
                    } label: {
                        HStack {
                            Text("\(cylinderSize) L").foregroundStyle(.primary)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.surfaceCard))
                    }
                }
            }

            // Gas
            VStack(alignment: .leading, spacing: 8) {
                labeledCaps(isDE ? "Standard-Gas" : "Default Gas")
                Picker("", selection: $defaultGas) {
                    Text("Air").tag("air")
                    Text("EAN32").tag("eanx32")
                    Text("EAN36").tag("eanx36")
                    Text("EAN40").tag("eanx40")
                }
                .pickerStyle(.segmented)
            }

            Text(isDE
                 ? "Kannst du später in Profil → Bearbeiten jederzeit ändern."
                 : "You can change these anytime in Profile → Edit.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Spacer(minLength: 0)
        }
    }

    // ═══════════════════════════════════════
    // MARK: - Step 4: Stamp

    private var stampStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer().frame(height: 6)

            stepHeader(
                title: isDE ? "Dein digitaler Stempel" : "Your Digital Stamp",
                subtitle: isDE
                    ? "Unterschreibe TGs wie Buddies sie signieren."
                    : "Sign dives like buddies sign them."
            )

            // Preview
            Group {
                if let data = stampData, let img = UIImage(data: data) {
                    VStack(spacing: 10) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 130)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.hairline, lineWidth: 1))

                        HStack(spacing: 12) {
                            Button {
                                showingStampGen = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                    Text(isDE ? "Neu generieren" : "Regenerate")
                                }
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.appAccent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.appAccent.opacity(0.10)))
                            }
                            .buttonStyle(.plain)

                            Button {
                                stampData = nil
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "trash")
                                    Text(isDE ? "Löschen" : "Delete")
                                }
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.appEmphasis)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.appEmphasis.opacity(0.10)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    VStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.hairline, style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                            .frame(height: 130)
                            .overlay(
                                VStack(spacing: 8) {
                                    Image(systemName: "seal")
                                        .font(.system(size: 28))
                                        .foregroundStyle(.tertiary)
                                    Text(isDE ? "Noch kein Stempel" : "No stamp yet")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                }
                            )

                        Button {
                            showingStampGen = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                Text(isDE ? "Stempel generieren" : "Generate stamp")
                            }
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color(uiColor: .systemBackground))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: DSRadius.m).fill(Color.appAccent))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Text(isDE
                 ? "Optional — du kannst ihn später jederzeit im Profil anlegen."
                 : "Optional — you can create one later from your profile.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Spacer(minLength: 0)
        }
    }

    // ═══════════════════════════════════════
    // MARK: - Shared UI Pieces

    private func stepHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
    }

    private func labeledCaps(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.secondary)
            .tracking(1.2)
    }

    // Same glyph used in LaunchScreen — kept local to avoid cross-file coupling
    private var diveGlyph: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let lensH = w * 0.55
            let lensW = w * 0.42
            let gap: CGFloat = 2
            ZStack {
                RoundedRectangle(cornerRadius: lensW * 0.32)
                    .stroke(Color.appAccent, lineWidth: w * 0.06)
                    .frame(width: lensW, height: lensH)
                    .offset(x: -(lensW + gap) / 2)
                RoundedRectangle(cornerRadius: lensW * 0.32)
                    .stroke(Color.appAccent, lineWidth: w * 0.06)
                    .frame(width: lensW, height: lensH)
                    .offset(x: (lensW + gap) / 2)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.appAccent)
                    .frame(width: gap + 6, height: lensH * 0.35)
                Circle()
                    .fill(Color.appEmphasis)
                    .frame(width: w * 0.04, height: w * 0.04)
            }
            .frame(width: w, height: geo.size.height)
        }
    }

    // ═══════════════════════════════════════
    // MARK: - Flow Control

    private func advance() {
        if step < totalSteps - 1 {
            withAnimation(.easeInOut(duration: 0.25)) { step += 1 }
        } else {
            // Final step: persist and finish
            persistAll()
            hasCompleted = true
            dismiss()
        }
    }

    private func skipOnboarding() {
        // Persist whatever has been entered so far, then exit
        persistAll()
        hasCompleted = true
        dismiss()
    }

    // ═══════════════════════════════════════
    // MARK: - Profile Persistence

    /// On first appear, pre-load any values already in the auto-bootstrapped
    /// profile so a user who partially completed onboarding, closed the app,
    /// and re-launched sees their work again.
    private func loadFromExistingProfile() {
        guard let p = profiles.first else { return }
        if !p.name.isEmpty { name = p.name }
        if !p.padiNumber.isEmpty { padiNumber = p.padiNumber }
        if !p.certLevel.isEmpty { certLevel = p.certLevel }
        if !p.email.isEmpty { email = p.email }
        profileImageData = p.profileImageData
        stampData = p.stampImageData
        useMetric = p.useMetric
        defaultSuit = p.defaultSuit
        defaultWeight = p.defaultWeight
        defaultGas = p.defaultGas

        // defaultCylinder is stored as "aluminum_12" etc.
        let parts = p.defaultCylinder.split(separator: "_").map(String.init)
        if parts.count == 2, let s = Int(parts[1]) {
            cylinderType = parts[0]
            cylinderSize = s
        }
    }

    private func persistAll() {
        // Get or create the DiverProfile — prefer the one matching our Apple ID
        // (may have synced from another device via CloudKit).
        let profile: DiverProfile
        let uid = AppleSignInService.shared.currentUserID
        if let uid, let match = profiles.first(where: { $0.appleUserID == uid }) {
            profile = match
        } else if let existing = profiles.first {
            profile = existing
        } else {
            let p = DiverProfile()
            ctx.insert(p)
            profile = p
        }

        profile.name = name.trimmingCharacters(in: .whitespaces)
        profile.padiNumber = padiNumber.trimmingCharacters(in: .whitespaces)
        profile.certLevel = certLevel
        profile.email = email.trimmingCharacters(in: .whitespaces)
        profile.isInstructor = ["OWSI", "MSDT", "IDC Staff", "CD"].contains(certLevel)

        profile.profileImageData = profileImageData
        profile.stampImageData = stampData

        profile.useMetric = useMetric
        profile.language = appLanguage

        profile.defaultSuit = defaultSuit
        profile.defaultWeight = defaultWeight
        profile.defaultCylinder = "\(cylinderType)_\(cylinderSize)"
        profile.defaultGas = defaultGas
    }

    // ═══════════════════════════════════════
    // MARK: - Photo loading

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item = item else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                // Downsample to 800px max for storage efficiency
                let resized = downsample(data: data, maxDim: 800)
                await MainActor.run { profileImageData = resized ?? data }
            }
        } catch {
            // Silently ignore — user can retry
        }
    }

    private func downsample(data: Data, maxDim: CGFloat) -> Data? {
        guard let img = UIImage(data: data) else { return nil }
        let maxSide = max(img.size.width, img.size.height)
        guard maxSide > maxDim else { return data }
        let scale = maxDim / maxSide
        let newSize = CGSize(width: img.size.width * scale, height: img.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            img.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.85)
    }
}

#Preview {
    OnboardingView()
        .modelContainer(for: [Dive.self, DiverProfile.self, DiveSite.self, Buddy.self, DiveSignature.self], inMemory: true)
}
