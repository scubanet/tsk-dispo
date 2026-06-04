import SwiftUI
import SwiftData

struct ConversationView: View {
  @Query(sort: \Turn.createdAt, order: .reverse) private var turns: [Turn]
  let vm: AppViewModel
  @Bindable var settings: SettingsStore
  let onSettings: () -> Void
  @State private var showClearConfirm = false

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 26) {
          ForEach(Array(turns.enumerated()), id: \.element.id) { idx, turn in
            TurnCardView(turn: turn, prominent: idx == 0) { vm.speak(turn) }
          }
        }
        .padding(20)
      }
      .overlay { if turns.isEmpty { hint } }
      RecordButton(phase: vm.phase) { Task { await vm.toggleRecording() } }
        .padding(20)
    }
    .background(Color(hex: 0xFAF9F4))
    .confirmationDialog(
      "Verlauf löschen?",
      isPresented: $showClearConfirm,
      titleVisibility: .visible
    ) {
      Button("Alle Texte und Übersetzungen löschen", role: .destructive) {
        vm.clearConversation()
      }
      Button("Abbrechen", role: .cancel) {}
    } message: {
      Text("Diese Aktion kann nicht rückgängig gemacht werden.")
    }
  }

  private var header: some View {
    HStack(spacing: 8) {
      languagePicker(selection: $settings.langA, label: "Sprache A")
      Image(systemName: "arrow.left.arrow.right")
        .foregroundStyle(Color.textTertiary)
        .accessibilityHidden(true)
      languagePicker(selection: $settings.langB, label: "Sprache B")
      Spacer()
      Button("Verlauf löschen", systemImage: "trash") { showClearConfirm = true }
        .labelStyle(.iconOnly)
        .foregroundStyle(Color.textSecondary)
        .frame(minWidth: 44, minHeight: 44)
        .disabled(turns.isEmpty)
      Button("Einstellungen", systemImage: "gearshape.fill", action: onSettings)
        .labelStyle(.iconOnly)
        .foregroundStyle(Color.textSecondary)
        .frame(minWidth: 44, minHeight: 44)
    }
    .padding(.horizontal, 16).padding(.vertical, 4)
  }

  /// Compact menu trigger: flag only in the header, flag + name in the dropdown.
  private func languagePicker(selection: Binding<AppLanguage>, label: String) -> some View {
    Menu {
      ForEach(AppLanguage.allCases) { lang in
        Button {
          selection.wrappedValue = lang
        } label: {
          Text("\(lang.flag) \(lang.displayName)")
        }
      }
    } label: {
      HStack(spacing: 2) {
        Text(selection.wrappedValue.flag).font(.title3)
        Image(systemName: "chevron.up.chevron.down")
          .font(.caption2)
          .foregroundStyle(Color.textTertiary)
      }
      .frame(minWidth: 44, minHeight: 44)
      .contentShape(Rectangle())
    }
    .accessibilityLabel(Text(label))
    .accessibilityValue(Text(selection.wrappedValue.displayName))
  }

  private var hint: some View {
    VStack(spacing: 8) {
      Image(systemName: "mic.circle").font(.system(size: 44)).foregroundStyle(Color.brandBlue)
      Text("Tippe auf \u{201E}Sprechen\u{201C} und leg los.").foregroundStyle(Color.textSecondary)
    }
  }
}
