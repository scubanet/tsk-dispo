import SwiftUI
import SwiftData

struct ConversationView: View {
  @Query(sort: \Turn.createdAt, order: .reverse) private var turns: [Turn]
  let vm: AppViewModel
  let onSettings: () -> Void

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
  }

  private var header: some View {
    HStack(spacing: 8) {
      Text(vm.pair.a.flag)
      Image(systemName: "arrow.left.arrow.right").foregroundStyle(Color.textTertiary)
      Text(vm.pair.b.flag)
      Text("Automatisch").font(.subheadline.weight(.medium)).foregroundStyle(Color.textSecondary)
      Spacer()
      Button(action: onSettings) { Image(systemName: "gearshape.fill").foregroundStyle(Color.textSecondary) }
    }
    .padding(.horizontal, 16).padding(.vertical, 10)
  }

  private var hint: some View {
    VStack(spacing: 8) {
      Image(systemName: "mic.circle").font(.system(size: 44)).foregroundStyle(Color.brandBlue)
      Text("Tippe auf \u{201E}Sprechen\u{201C} und leg los.").foregroundStyle(Color.textSecondary)
    }
  }
}
