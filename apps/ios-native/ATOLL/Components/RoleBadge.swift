import SwiftUI

struct RoleBadge: View {
    let role: AssignmentRole

    var body: some View {
        Text(label)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    private var label: String {
        switch role {
        case .haupt: "Haupt"
        case .assist: "Assist"
        case .dmt: "DMT"
        }
    }

    private var color: Color {
        switch role {
        case .haupt: .blue
        case .assist: .orange
        case .dmt: .purple
        }
    }
}
