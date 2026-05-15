import SwiftUI

struct StatusChip: View {
    let status: CourseStatus

    var body: some View {
        Text(label)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: Capsule())
            .foregroundStyle(color)
    }

    private var label: String {
        switch status {
        case .confirmed: "Bestätigt"
        case .tentative: "Provisorisch"
        case .cancelled: "Abgesagt"
        case .completed: "Abgeschlossen"
        }
    }

    private var color: Color {
        switch status {
        case .confirmed: .green
        case .tentative: .orange
        case .cancelled: .red
        case .completed: .secondary
        }
    }
}
