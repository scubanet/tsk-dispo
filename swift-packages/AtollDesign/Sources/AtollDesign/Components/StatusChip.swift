import SwiftUI
import AtollCore

public struct StatusChip: View {
  public let status: CourseStatus

  public init(status: CourseStatus) {
    self.status = status
  }

  public var body: some View {
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
