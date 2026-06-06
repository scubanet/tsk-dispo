import SwiftUI
import SwiftData

/// Data management actions: export, load sample data, deduplicate dives,
/// delete all data. Destructive actions are confirmed via ProfileTab's
/// @State-driven dialogs; this card just exposes a callback per button.
///
/// Inputs are pure read-only (counts and result-messages). All mutating
/// logic stays in ProfileTab.
struct DataManagementCard: View {
    let dives: [Dive]
    let isLogbookEmpty: Bool
    let duplicateCount: Int
    let dedupeResultMessage: String?
    let sampleLoadedMessage: String?
    let onExport: () -> Void
    let onLoadSampleData: () -> Void
    let onDedupe: () -> Void
    let onImport: () -> Void
    let onDeleteAll: () -> Void

    var body: some View {
        VStack(spacing: 1) {
            // Sample-Data loader — only visible when the logbook is empty.
            // Opt-in by design: auto-seeding in a CloudKit env would create
            // duplicates as soon as sync catches up on secondary devices.
            if isLogbookEmpty {
                Button {
                    onLoadSampleData()
                } label: {
                    settingsRow(
                        icon: "sparkles",
                        label: L10n.currentLanguage == "de" ? "Beispieldaten laden" : "Load Sample Data"
                    ) {
                        HStack(spacing: 6) {
                            Text(L10n.currentLanguage == "de" ? "4 TGs" : "4 dives")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.appAccent)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            // Always visible so users know the feature exists; shows badge if
            // duplicates present.
            Button {
                onDedupe()
            } label: {
                settingsRow(
                    icon: "rectangle.on.rectangle.slash",
                    label: L10n.currentLanguage == "de" ? "Duplikate bereinigen" : "Clean up duplicates"
                ) {
                    HStack(spacing: 6) {
                        if duplicateCount > 0 {
                            Text("\(duplicateCount)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.appEmphasis))
                        } else {
                            Text(L10n.currentLanguage == "de" ? "Keine" : "None")
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .buttonStyle(.plain)

            // Always visible — entry-point for UDDF/dive-computer file import.
            Button {
                onImport()
            } label: {
                settingsRow(
                    icon: "square.and.arrow.down",
                    label: L10n.currentLanguage == "de" ? "Tauchgänge importieren" : "Import dives"
                ) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        }
    }
}
