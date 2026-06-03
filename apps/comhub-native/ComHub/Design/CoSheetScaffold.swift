import SwiftUI

/// Einheitliches Sheet-Gerüst: Kopf (Icon + Titel) · scrollbarer Inhalt (Form) ·
/// Fussleiste (Abbrechen · optional Loeschen · primärer CTA). Konsistenter
/// CoHub-Look fuer alle Erfassen/Bearbeiten-Sheets.
struct CoSheetScaffold<Content: View>: View {
  let icon: String
  let tint: Color
  let title: String
  var subtitle: String? = nil
  var saveTitle: String = "Sichern"
  let canSave: Bool
  let onSave: () -> Void
  var onDelete: (() -> Void)? = nil
  @ViewBuilder var content: () -> Content
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(spacing: 0) {
      // Kopf
      HStack(spacing: 12) {
        Image(systemName: icon)
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(.white)
          .frame(width: 34, height: 34)
          .background(tint, in: RoundedRectangle(cornerRadius: 9))
        VStack(alignment: .leading, spacing: 1) {
          Text(title).font(.system(size: 16, weight: .bold))
          if let subtitle { Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary) }
        }
        Spacer(minLength: 0)
      }
      .padding(.horizontal, 18).padding(.top, 18).padding(.bottom, 12)

      Divider()

      // Inhalt
      Form { content() }
        .formStyle(.grouped)

      Divider()

      // Fussleiste
      HStack(spacing: 10) {
        if let onDelete {
          Button(role: .destructive) { onDelete(); dismiss() } label: {
            Image(systemName: "trash")
          }
          .buttonStyle(.bordered)
        }
        Spacer(minLength: 0)
        Button("Abbrechen") { dismiss() }
          .buttonStyle(.bordered)
          .keyboardShortcut(.cancelAction)
        Button(saveTitle) { onSave(); dismiss() }
          .buttonStyle(.borderedProminent)
          .keyboardShortcut(.defaultAction)
          .disabled(!canSave)
      }
      .padding(.horizontal, 18).padding(.vertical, 12)
    }
    // Header-Tile traegt die Modulfarbe; Controls + primärer CTA bleiben Accent
    // (sonst wirkt z. B. ein roter „Sichern"-Knopf wie eine destruktive Aktion).
    .tint(CoColor.accent)
    #if os(macOS)
    .frame(minWidth: 480, idealWidth: 520, minHeight: 520)
    #endif
    #if os(iOS)
    .presentationDragIndicator(.visible)
    #endif
  }
}
