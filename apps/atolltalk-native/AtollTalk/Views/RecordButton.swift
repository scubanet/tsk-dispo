import SwiftUI

struct RecordButton: View {
  let phase: AppViewModel.Phase
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        Image(systemName: phase == .recording ? "stop.fill" : "mic.fill")
        Text(label)
      }
      .font(.title3.weight(.semibold))
      .frame(maxWidth: .infinity)
      .padding(.vertical, 18)
      .background(background, in: .rect(cornerRadius: 18))
      .foregroundStyle(.white)
    }
    .disabled(isBusy)
  }

  private var label: String {
    switch phase {
    case .recording:    "Stopp"
    case .transcribing: "Höre zu…"
    case .translating:  "Übersetze…"
    default:            "Sprechen"
    }
  }
  private var background: Color { phase == .recording ? Color(hex: 0xA32D2D) : .brandBlue }
  private var isBusy: Bool {
    switch phase { case .transcribing, .translating: return true; default: return false }
  }
}
