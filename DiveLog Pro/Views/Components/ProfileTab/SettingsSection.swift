import SwiftUI
import SwiftData

/// User-facing settings card: language, units, default cylinder/suit,
/// QR code, export, and dive-computer placeholder.
///
/// `@AppStorage` values flow in/out via `@Binding` so ProfileTab remains
/// the authoritative source for those keys.
/// Sheet triggers are surfaced as simple `() -> Void` closures so this
/// component stays independent of ProfileTab's `@State` booleans.
struct SettingsSection: View {
    let profile: DiverProfile?
    @Binding var language: String
    let onShowQR: () -> Void
    let onShowExport: () -> Void

    var body: some View {
        VStack(spacing: 1) {
            settingsRow(icon: "globe", label: L10n.currentLanguage == "de" ? "Sprache" : "Language") {
                Picker("", selection: $language) {
                    Text("English").tag("en")
                    Text("Deutsch").tag("de")
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }

            settingsRow(icon: "ruler", label: L10n.currentLanguage == "de" ? "Einheiten" : "Units") {
                let unitText: String = (profile?.useMetric ?? true)
                    ? (L10n.currentLanguage == "de" ? "Metrisch" : "Metric")
                    : "Imperial"
                Text(unitText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.appAccent)
            }

            if let p = profile {
                settingsRow(icon: "gauge.with.dots.needle.bottom.50percent",
                            label: L10n.currentLanguage == "de" ? "Standard-Flasche" : "Default Cylinder") {
                    Text(cylinderLabel(p.defaultCylinder))
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                }
                settingsRow(icon: "figure.pool.swim",
                            label: L10n.currentLanguage == "de" ? "Standard-Anzug" : "Default Suit") {
                    Text(suitLabel(p.defaultSuit))
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                }

                Button {
                    onShowQR()
                } label: {
                    settingsRow(icon: "qrcode", label: L10n.myQRTitle) {
                        HStack(spacing: 6) {
                            Text(L10n.currentLanguage == "de" ? "Anzeigen" : "Show")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.appAccent)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(p.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Button {
                onShowExport()
            } label: {
                settingsRow(icon: "square.and.arrow.up", label: "Export") {
                    HStack(spacing: 6) {
                        Text("PDF / CSV")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.appAccent)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .buttonStyle(.plain)

            settingsRow(icon: "antenna.radiowaves.left.and.right", label: "Dive Computer") {
                Text(L10n.currentLanguage == "de" ? "Bald verfügbar" : "Coming soon")
                    .font(.system(size: 12)).foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Helpers

    private func cylinderLabel(_ raw: String) -> String {
        let parts = raw.split(separator: "_").map(String.init)
        let type = parts.first ?? raw
        let size = parts.count > 1 ? parts[1] : ""
        let typeLabel: String
        switch type {
        case "aluminum": typeLabel = L10n.currentLanguage == "de" ? "Alu" : "Aluminum"
        case "steel":    typeLabel = L10n.currentLanguage == "de" ? "Stahl" : "Steel"
        default:         typeLabel = type.capitalized
        }
        return size.isEmpty ? typeLabel : "\(typeLabel) \(size)L"
    }

    private func suitLabel(_ raw: String) -> String {
        switch raw {
        case "shorty":   return "Shorty"
        case "3mm":      return "3 mm"
        case "5mm":      return "5 mm"
        case "7mm":      return "7 mm"
        case "drysuit":  return L10n.currentLanguage == "de" ? "Trockenanzug" : "Drysuit"
        case "none":     return L10n.currentLanguage == "de" ? "Keiner" : "None"
        default:         return raw.capitalized
        }
    }
}
