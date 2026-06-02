import SwiftUI
import AtollHub

/// Ein positionierter Event-Block im Tagesgitter.
struct EventBlockView: View {
  let event: UnifiedEvent

  private var tint: Color {
    if let hex = event.colorHex, let c = Color(hex: hex) { return c }
    return event.source.type == .atoll ? CoColor.accent : .secondary
  }

  private static let time: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "HH:mm"
    f.timeZone = TimeZone(identifier: "Europe/Zurich"); return f
  }()

  var body: some View {
    VStack(alignment: .leading, spacing: 1) {
      Text(event.title).font(.system(size: 11.5, weight: .semibold)).lineLimit(1)
      Text("\(Self.time.string(from: event.start))\(event.location.map { " · \($0)" } ?? "")")
        .font(.system(size: 10.5)).foregroundStyle(.secondary).lineLimit(1)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding(.horizontal, 6).padding(.vertical, 3)
    .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 6))
    .overlay(alignment: .leading) {
      RoundedRectangle(cornerRadius: 2).fill(tint).frame(width: 3)
    }
    .clipShape(RoundedRectangle(cornerRadius: 6))
  }
}
