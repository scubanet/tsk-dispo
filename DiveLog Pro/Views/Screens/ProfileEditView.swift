import SwiftUI
import SwiftData
import PhotosUI
import UIKit

// ═══════════════════════════════════════
// MARK: - Profile Edit View
// ═══════════════════════════════════════

/// Full edit sheet for DiverProfile. Covers identity, photo, stamp, smart
/// defaults, and preferences. Saves back to the SwiftData model on "Save".
struct ProfileEditView: View {
    let profile: DiverProfile
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Environment(\.atollBridge) private var atollBridge

    // Identity
    @State private var name: String = ""
    @State private var padiNumber: String = ""
    @State private var certLevel: String = "OWD"
    @State private var email: String = ""
    @State private var phone: String = ""
    @State private var profileImageData: Data? = nil

    // Stamp
    @State private var stampImageData: Data? = nil

    // Smart defaults
    @State private var defaultSuit: String = "shorty"
    @State private var defaultWeight: String = "2"
    @State private var defaultCylinderType: String = "aluminum"
    @State private var defaultCylinderSize: String = "12"
    @State private var defaultGas: String = "air"
    @State private var defaultDiveCenter: String = ""

    // Preferences
    @State private var useMetric: Bool = true
    @AppStorage("appLanguage") private var language: String = "en"

    // Pickers
    @State private var profilePickerItem: PhotosPickerItem?
    @State private var profilePickerShown = false
    @State private var stampPickerItem: PhotosPickerItem?
    @State private var stampPickerShown = false
    @State private var showingStampGenerator = false

    private let certLevels: [(String, String)] = [
        ("OWD", "Open Water Diver"),
        ("AOWD", "Advanced Open Water"),
        ("Rescue", "Rescue Diver"),
        ("DM", "Divemaster"),
        ("OWSI", "Open Water Scuba Instructor"),
        ("MSDT", "Master Scuba Diver Trainer"),
        ("IDC Staff", "IDC Staff Instructor"),
        ("Master Instructor", "Master Instructor"),
        ("CD", "Course Director"),
    ]

    private let suitOptions = [("none", "None"), ("shorty", "Shorty"), ("3mm", "3mm"), ("5mm", "5mm"), ("7mm", "7mm"), ("semi_dry", "Semi-dry"), ("drysuit", "Drysuit")]
    private let gasOptions = [("air", "Air"), ("eanx32", "EANx32"), ("eanx36", "EANx36"), ("eanx40", "EANx40")]
    private let cylinderTypeOptions = [("aluminum", "Alu"), ("steel", "Steel")]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.deepOcean.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        identitySection
                        stampSection
                        smartDefaultsSection
                        preferencesSection
                    }
                    .padding(20)
                    .padding(.bottom, 60)
                }
            }
            .navigationTitle(L10n.currentLanguage == "de" ? "Profil bearbeiten" : "Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.currentLanguage == "de" ? "Abbrechen" : "Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white.opacity(0.7))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        saveProfile()
                    } label: {
                        Text(L10n.currentLanguage == "de" ? "Speichern" : "Save")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.seafoam)
                    }
                }
            }
            .toolbarBackground(Color.deepOcean, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onAppear(perform: loadFromProfile)
            .photosPicker(
                isPresented: $profilePickerShown,
                selection: $profilePickerItem,
                matching: .images,
                photoLibrary: .shared()
            )
            .photosPicker(
                isPresented: $stampPickerShown,
                selection: $stampPickerItem,
                matching: .images,
                photoLibrary: .shared()
            )
            .onChange(of: profilePickerItem) { _, item in
                guard let item else { return }
                Task { await loadPickedImage(item: item, into: \.profileImageData) }
            }
            .onChange(of: stampPickerItem) { _, item in
                guard let item else { return }
                Task { await loadPickedImage(item: item, into: \.stampImageData) }
            }
            .sheet(isPresented: $showingStampGenerator) {
                StampGeneratorView(
                    name: name,
                    padiNumber: padiNumber,
                    certLevel: certLevel
                ) { generatedData in
                    stampImageData = generatedData
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // ═══════════════════════════════════════
    // MARK: - Identity Section
    // ═══════════════════════════════════════

    private var identitySection: some View {
        VStack(spacing: 14) {
            SectionTitle(title: L10n.currentLanguage == "de" ? "Identität" : "Identity")

            // Profile image picker
            Button { profilePickerShown = true } label: {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.oceanBlue.opacity(0.3), .seafoam.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 110, height: 110)

                    if let data = profileImageData, let img = UIImage(data: data) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 110, height: 110)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 46))
                            .foregroundColor(.white.opacity(0.4))
                    }

                    // Camera badge
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "camera.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(Color.oceanBlue))
                                .overlay(Circle().stroke(Color.deepOcean, lineWidth: 2))
                        }
                    }
                    .frame(width: 110, height: 110)
                }
            }
            .buttonStyle(.plain)

            FormField(label: L10n.currentLanguage == "de" ? "Name" : "Name", text: $name, placeholder: "Max Mustermann")
            FormField(label: "PADI Number", text: $padiNumber, placeholder: "335680", keyboard: .numberPad)

            // Cert level picker
            VStack(alignment: .leading, spacing: 8) {
                Text((L10n.currentLanguage == "de" ? "Zertifizierung" : "Certification").uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.labelDim)
                    .tracking(1.2)
                Menu {
                    ForEach(certLevels, id: \.0) { cert in
                        Button {
                            certLevel = cert.0
                        } label: {
                            HStack {
                                Text(cert.1)
                                if cert.0 == certLevel {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(certLevels.first(where: { $0.0 == certLevel })?.1 ?? certLevel)
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.035)))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                }
            }

            FormField(label: "Email", text: $email, placeholder: "diver@example.com", keyboard: .emailAddress)
            FormField(label: L10n.currentLanguage == "de" ? "Telefon" : "Phone", text: $phone, placeholder: "+49 ...", keyboard: .phonePad)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.cardBorder, lineWidth: 1))
    }

    // ═══════════════════════════════════════
    // MARK: - Stamp Section
    // ═══════════════════════════════════════

    private var stampSection: some View {
        VStack(spacing: 14) {
            SectionTitle(title: L10n.currentLanguage == "de" ? "Digitaler Stempel" : "Digital Stamp")

            // Stamp preview
            Group {
                if let data = stampImageData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 140)
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.seafoam.opacity(0.4), style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                        .frame(height: 120)
                        .overlay(
                            VStack(spacing: 6) {
                                Image(systemName: "seal")
                                    .font(.system(size: 22))
                                    .foregroundColor(.white.opacity(0.3))
                                Text(L10n.currentLanguage == "de" ? "Noch kein Stempel" : "No stamp yet")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.3))
                            }
                        )
                }
            }

            HStack(spacing: 10) {
                Button { showingStampGenerator = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "wand.and.stars")
                        Text(L10n.currentLanguage == "de" ? "Generieren" : "Generate")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.seafoam)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.seafoam.opacity(0.1)))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.seafoam.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button { stampPickerShown = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.fill")
                        Text(L10n.currentLanguage == "de" ? "Hochladen" : "Upload")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.oceanBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.oceanBlue.opacity(0.1)))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.oceanBlue.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)

                if stampImageData != nil {
                    Button {
                        stampImageData = nil
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.coral)
                            .frame(width: 40, height: 38)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.coral.opacity(0.1)))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.coral.opacity(0.25), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.cardBorder, lineWidth: 1))
    }

    // ═══════════════════════════════════════
    // MARK: - Smart Defaults
    // ═══════════════════════════════════════

    private var smartDefaultsSection: some View {
        VStack(spacing: 14) {
            SectionTitle(title: L10n.currentLanguage == "de" ? "Standard-Ausrüstung" : "Smart Defaults")

            Text(L10n.currentLanguage == "de"
                 ? "Wird bei neuen TGs automatisch übernommen."
                 : "Pre-filled into new dive logs.")
                .font(.system(size: 11))
                .foregroundColor(.textDim)
                .frame(maxWidth: .infinity, alignment: .leading)

            SegmentPicker(label: L10n.suitLabel, options: [("none", "None"), ("shorty", "Shorty"), ("3mm", "3mm"), ("5mm", "5mm")], selected: $defaultSuit)
            SegmentPicker(label: " ", options: [("7mm", "7mm"), ("semi_dry", "Semi-dry"), ("drysuit", "Drysuit")], selected: $defaultSuit)

            HStack(spacing: 12) {
                FormField(label: L10n.weightLabel + " (kg)", text: $defaultWeight, placeholder: "2", keyboard: .decimalPad)
                FormField(label: L10n.cylinderLabel + " (L)", text: $defaultCylinderSize, placeholder: "12", keyboard: .decimalPad)
            }

            SegmentPicker(label: L10n.currentLanguage == "de" ? "Flaschentyp" : "Cylinder Type", options: cylinderTypeOptions, selected: $defaultCylinderType)
            SegmentPicker(label: L10n.gasLabel, options: gasOptions, selected: $defaultGas)

            FormField(label: L10n.diveCenterLabel, text: $defaultDiveCenter, placeholder: "e.g. Amun Ini")
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.cardBorder, lineWidth: 1))
    }

    // ═══════════════════════════════════════
    // MARK: - Preferences
    // ═══════════════════════════════════════

    private var preferencesSection: some View {
        VStack(spacing: 14) {
            SectionTitle(title: L10n.currentLanguage == "de" ? "Einstellungen" : "Preferences")

            VStack(alignment: .leading, spacing: 8) {
                Text((L10n.currentLanguage == "de" ? "Sprache" : "Language").uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.labelDim)
                    .tracking(1.2)
                Picker("", selection: $language) {
                    Text("English").tag("en")
                    Text("Deutsch").tag("de")
                }
                .pickerStyle(.segmented)
            }

            Toggle(isOn: $useMetric) {
                HStack(spacing: 8) {
                    Image(systemName: "ruler")
                        .foregroundColor(.seafoam)
                    Text(L10n.currentLanguage == "de" ? "Metrische Einheiten" : "Metric Units")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .tint(.seafoam)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.cardBorder, lineWidth: 1))
    }

    // ═══════════════════════════════════════
    // MARK: - Load & Save
    // ═══════════════════════════════════════

    private func loadFromProfile() {
        name = profile.name
        padiNumber = profile.padiNumber
        certLevel = profile.certLevel
        email = profile.email
        phone = profile.phone
        profileImageData = profile.profileImageData
        stampImageData = profile.stampImageData

        defaultSuit = profile.defaultSuit
        defaultWeight = String(profile.defaultWeight)
        defaultGas = profile.defaultGas
        defaultDiveCenter = profile.defaultDiveCenter

        // defaultCylinder is stored as "aluminum_12" or similar
        let parts = profile.defaultCylinder.split(separator: "_", maxSplits: 1)
        if parts.count == 2 {
            defaultCylinderType = String(parts[0])
            defaultCylinderSize = String(parts[1])
        } else {
            defaultCylinderType = profile.defaultCylinder.isEmpty ? "aluminum" : profile.defaultCylinder
            defaultCylinderSize = "12"
        }

        useMetric = profile.useMetric
    }

    private func republishToAtollBridge() {
        guard let bridge = atollBridge else { return }
        let container = ctx.container
        Task { @MainActor in
            await DiveLogBridgePublisher(container: container, bridge: bridge).publish()
        }
    }

    private func saveProfile() {
        profile.name = name.trimmingCharacters(in: .whitespaces)
        profile.padiNumber = padiNumber.trimmingCharacters(in: .whitespaces)
        profile.certLevel = certLevel
        profile.isInstructor = ["OWSI", "MSDT", "IDC Staff", "Master Instructor", "CD"].contains(certLevel)
        profile.email = email.trimmingCharacters(in: .whitespaces)
        profile.phone = phone.trimmingCharacters(in: .whitespaces)
        profile.profileImageData = profileImageData
        profile.stampImageData = stampImageData

        profile.defaultSuit = defaultSuit
        profile.defaultWeight = Double(defaultWeight) ?? 2
        profile.defaultCylinder = "\(defaultCylinderType)_\(defaultCylinderSize)"
        profile.defaultGas = defaultGas
        profile.defaultDiveCenter = defaultDiveCenter.trimmingCharacters(in: .whitespaces)
        profile.useMetric = useMetric
        profile.language = language

        republishToAtollBridge()
        dismiss()
    }

    // ═══════════════════════════════════════
    // MARK: - Image Loading
    // ═══════════════════════════════════════

    private func loadPickedImage(
        item: PhotosPickerItem,
        into keyPath: ReferenceWritableKeyPath<ProfileEditView, Data?>
    ) async {
        // PhotosPickerItem → Data → downsample → JPEG
        guard let data = try? await item.loadTransferable(type: Data.self),
              let img = UIImage(data: data) else { return }
        let resized = downsample(image: img, maxDimension: 800)
        let jpeg = resized.jpegData(compressionQuality: 0.85)
        await MainActor.run {
            // Can't write through keypath on self here, so handle manually
            _ = keyPath // silence warning
            if keyPath == \ProfileEditView.profileImageData {
                profileImageData = jpeg
            } else if keyPath == \ProfileEditView.stampImageData {
                stampImageData = jpeg
            }
        }
    }

    private func downsample(image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longEdge = max(size.width, size.height)
        guard longEdge > maxDimension else { return image }
        let scale = maxDimension / longEdge
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// ═══════════════════════════════════════
// MARK: - Stamp Generator
// ═══════════════════════════════════════

/// Generates a clean text-based stamp from the user's identity.
/// Returns a PNG via the onSave callback.
struct StampGeneratorView: View {
    let name: String
    let padiNumber: String
    let certLevel: String
    let onSave: (Data) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedStyle: Int = 0

    private let styles: [String] = ["Classic", "Ocean", "Bold"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.deepOcean.ignoresSafeArea()

                VStack(spacing: 20) {
                    Text(L10n.currentLanguage == "de"
                         ? "Wähle einen Stempel-Stil:"
                         : "Choose a stamp style:")
                        .font(.system(size: 13))
                        .foregroundColor(.textDim)
                        .padding(.top, 20)

                    // Preview
                    if let preview = renderStamp(style: selectedStyle) {
                        Image(uiImage: preview)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 160)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.seafoam.opacity(0.3), lineWidth: 1))
                            .padding(.horizontal, 20)
                    }

                    // Style picker
                    HStack(spacing: 10) {
                        ForEach(0..<styles.count, id: \.self) { idx in
                            Button {
                                selectedStyle = idx
                            } label: {
                                Text(styles[idx])
                                    .font(.system(size: 13, weight: selectedStyle == idx ? .bold : .medium))
                                    .foregroundColor(selectedStyle == idx ? .seafoam : .white.opacity(0.5))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(selectedStyle == idx ? Color.oceanBlue.opacity(0.25) : Color.cardBg)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(selectedStyle == idx ? Color.seafoam.opacity(0.3) : Color.cardBorder, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer()
                }
            }
            .navigationTitle(L10n.currentLanguage == "de" ? "Stempel erstellen" : "Create Stamp")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.currentLanguage == "de" ? "Abbrechen" : "Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white.opacity(0.7))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.currentLanguage == "de" ? "Übernehmen" : "Apply") {
                        if let img = renderStamp(style: selectedStyle),
                           let data = img.pngData() {
                            onSave(data)
                        }
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.seafoam)
                }
            }
            .toolbarBackground(Color.deepOcean, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }

    // ═══════════════════════════════════════

    private func renderStamp(style: Int) -> UIImage? {
        let size = CGSize(width: 600, height: 240)
        let format = UIGraphicsImageRendererFormat()
        format.scale = UITraitCollection.current.displayScale
        format.opaque = true

        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let cgCtx = ctx.cgContext

            // Background
            UIColor.white.setFill()
            cgCtx.fill(CGRect(origin: .zero, size: size))

            let displayName = name.isEmpty ? "YOUR NAME" : name
            let displayPadi = padiNumber.isEmpty ? "PADI #" : "PADI #\(padiNumber)"
            let certFull = certFullName(certLevel)

            switch style {
            case 0:  drawClassic(in: cgCtx, size: size, name: displayName, padi: displayPadi, cert: certFull)
            case 1:  drawOcean(in: cgCtx, size: size, name: displayName, padi: displayPadi, cert: certFull)
            default: drawBold(in: cgCtx, size: size, name: displayName, padi: displayPadi, cert: certFull)
            }
        }
    }

    private func certFullName(_ code: String) -> String {
        switch code {
        case "OWD":   return "Open Water Diver"
        case "AOWD":  return "Advanced Open Water Diver"
        case "DM":    return "Divemaster"
        case "OWSI":  return "Open Water Scuba Instructor"
        case "MSDT":  return "Master Scuba Diver Trainer"
        case "CD":    return "Course Director"
        default:      return code
        }
    }

    // MARK: Style 0 — Classic (centered serif-ish, bordered)

    private func drawClassic(in ctx: CGContext, size: CGSize, name: String, padi: String, cert: String) {
        // Double border
        UIColor(Color.deepOcean).setStroke()
        ctx.setLineWidth(3)
        ctx.stroke(CGRect(x: 16, y: 16, width: size.width - 32, height: size.height - 32))
        ctx.setLineWidth(1)
        ctx.stroke(CGRect(x: 26, y: 26, width: size.width - 52, height: size.height - 52))

        drawText(name.uppercased(), at: CGPoint(x: size.width / 2, y: 70), size: 30, weight: .bold, align: .center, color: UIColor(Color.deepOcean))
        drawText(padi, at: CGPoint(x: size.width / 2, y: 115), size: 18, weight: .medium, align: .center, color: UIColor(Color.oceanBlue))

        // Divider
        UIColor(Color.oceanBlue).withAlphaComponent(0.4).setStroke()
        ctx.setLineWidth(1)
        ctx.move(to: CGPoint(x: size.width / 2 - 80, y: 145))
        ctx.addLine(to: CGPoint(x: size.width / 2 + 80, y: 145))
        ctx.strokePath()

        drawText(cert, at: CGPoint(x: size.width / 2, y: 175), size: 15, weight: .regular, align: .center, color: UIColor(Color.deepOcean))
    }

    // MARK: Style 1 — Ocean (left-aligned, oceanBlue accents)

    private func drawOcean(in ctx: CGContext, size: CGSize, name: String, padi: String, cert: String) {
        // Left accent bar
        UIColor(Color.oceanBlue).setFill()
        ctx.fill(CGRect(x: 20, y: 30, width: 6, height: size.height - 60))

        drawText(name, at: CGPoint(x: 50, y: 55), size: 32, weight: .bold, align: .left, color: UIColor(Color.deepOcean))
        drawText(cert, at: CGPoint(x: 50, y: 100), size: 16, weight: .semibold, align: .left, color: UIColor(Color.oceanBlue))
        drawText(padi, at: CGPoint(x: 50, y: 155), size: 18, weight: .medium, align: .left, color: UIColor(Color.deepOcean).withAlphaComponent(0.7))
    }

    // MARK: Style 2 — Bold

    private func drawBold(in ctx: CGContext, size: CGSize, name: String, padi: String, cert: String) {
        // Solid deep ocean band
        UIColor(Color.deepOcean).setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: size.width, height: 80))

        drawText(cert.uppercased(), at: CGPoint(x: size.width / 2, y: 35), size: 18, weight: .heavy, align: .center, color: UIColor(Color.seafoam))

        drawText(name, at: CGPoint(x: size.width / 2, y: 125), size: 34, weight: .black, align: .center, color: UIColor(Color.deepOcean))
        drawText(padi, at: CGPoint(x: size.width / 2, y: 180), size: 16, weight: .medium, align: .center, color: UIColor(Color.oceanBlue))
    }

    // MARK: Drawing helper

    private enum Align { case left, center }

    private func drawText(_ text: String, at point: CGPoint, size: CGFloat, weight: UIFont.Weight, align: Align, color: UIColor) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = align == .center ? .center : .left

        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        let str = NSAttributedString(string: text, attributes: attrs)

        let boundingSize = CGSize(width: 560, height: CGFloat.greatestFiniteMagnitude)
        let rect = str.boundingRect(with: boundingSize, options: [.usesLineFragmentOrigin], context: nil)
        let drawPoint: CGPoint
        switch align {
        case .center:
            drawPoint = CGPoint(x: point.x - rect.width / 2, y: point.y - rect.height / 2)
        case .left:
            drawPoint = CGPoint(x: point.x, y: point.y - rect.height / 2)
        }
        str.draw(at: drawPoint)
    }
}
