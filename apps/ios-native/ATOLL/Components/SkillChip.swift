import SwiftUI

struct SkillChip: View {
  let initials: String
  /// Reserviert für Long-Press-Detail-Sheet (post-Pitch) — wird aktuell
  /// vom Component nicht gelesen, aber vom Parent für `onTap` benötigt.
  let participantId: UUID
  let isDone: Bool
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      HStack(spacing: 4) {
        Text(initials)
          .font(.caption.bold().monospacedDigit())
          .foregroundStyle(isDone ? Color(red: 0.02, green: 0.20, blue: 0.17) : Color.primary.opacity(0.7))
        if isDone {
          Image(systemName: "checkmark")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(Color(red: 0.02, green: 0.20, blue: 0.17))
        }
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 5)
      .frame(maxWidth: .infinity)
      .background(
        RoundedRectangle(cornerRadius: 6)
          .fill(isDone ? Color(red: 0.62, green: 0.88, blue: 0.79) : Color(.systemGray6))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 6)
          .stroke(isDone ? Color.clear : Color(.systemGray3), lineWidth: 0.5)
      )
    }
    .buttonStyle(.plain)
  }
}
