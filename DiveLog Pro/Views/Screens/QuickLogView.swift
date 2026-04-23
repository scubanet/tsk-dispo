import SwiftUI
import SwiftData

/// Placeholder — full implementation in Task 28 (Phase 3 — Drop-In Magic).
/// Currently renders an empty form so the LogbookTab Menu compiles.
struct QuickLogView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.appAccent)
                Text(L10n.currentLanguage == "de" ? "Quick-Log" : "Quick Log")
                    .font(.title2.bold())
                Text(L10n.currentLanguage == "de"
                     ? "Implementierung folgt in Phase 3."
                     : "Full implementation lands in Phase 3.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(L10n.currentLanguage == "de" ? "Quick-Log" : "Quick Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.currentLanguage == "de" ? "Schließen" : "Close") { dismiss() }
                }
            }
        }
    }
}
