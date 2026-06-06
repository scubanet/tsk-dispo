import SwiftUI

struct SkillStatusBadge: View {
    let status: SkillStatus
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.sfSymbol)
                .font(.system(size: compact ? 11 : 13, weight: .semibold))
            if !compact {
                Text(status.displayLabel)
                    .font(.system(size: 11, weight: .medium))
            }
        }
        .foregroundStyle(status.color)
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(status.color.opacity(0.12))
        )
        .accessibilityLabel(status.displayLabel)
    }
}

#Preview {
    VStack(spacing: 8) {
        ForEach(SkillStatus.allCases, id: \.self) { s in
            HStack {
                SkillStatusBadge(status: s)
                SkillStatusBadge(status: s, compact: true)
            }
        }
    }
    .padding()
}
