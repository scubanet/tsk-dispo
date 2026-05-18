import SwiftUI
import AtollDesign

/// Red current-time line with a Liquid-Glass pill carrying the live `HH:mm`
/// timestamp. The pill anchors the line at the left edge of the events column.
///
/// Refreshes once per minute via `Task.sleep` — Swift-6 / strict-concurrency
/// clean, no `Timer.publish` callback to argue with.
struct NowIndicator: View {
  let hourHeight: CGFloat

  @State private var now = Date()

  var body: some View {
    let cal = Calendar.current
    let hour = cal.component(.hour, from: now)
    let minute = cal.component(.minute, from: now)
    let yOffset = (Double(hour) + Double(minute) / 60.0) * Double(hourHeight)

    HStack(spacing: 4) {
      Text(timeString)
        .font(.caption2)
        .fontWeight(.semibold)
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .atollGlassPill(tint: .red)
      Rectangle()
        .fill(Color.red)
        .frame(height: 1.5)
    }
    .offset(y: yOffset - 9)  // centre pill on the time line
    .task {
      // Tick every minute while the view is mounted.
      while !Task.isCancelled {
        now = Date()
        try? await Task.sleep(for: .seconds(60))
      }
    }
  }

  private var timeString: String {
    let f = DateFormatter()
    f.dateFormat = "HH:mm"
    return f.string(from: now)
  }
}
