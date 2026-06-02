import SwiftUI
import AtollHub

/// Eine Event-Zeile: Zeit (oder „ganztägig"), Titel, Ort, Quell-Badge.
struct UnifiedEventRow: View {
  let event: UnifiedEvent

  private static let timeFormatter: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "HH:mm"
    f.timeZone = TimeZone(identifier: "Europe/Zurich"); return f
  }()

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      RoundedRectangle(cornerRadius: 2)
        .fill(event.source.type == .atoll ? Color.accentColor : Color.secondary)
        .frame(width: 4)
      VStack(alignment: .leading, spacing: 2) {
        Text(event.title).font(.callout.weight(.medium)).lineLimit(1)
        HStack(spacing: 6) {
          Text(event.isAllDay ? "ganztägig"
               : Self.timeFormatter.string(from: event.start))
            .font(.caption).foregroundStyle(.secondary)
          if let loc = event.location, !loc.isEmpty {
            Text(loc).font(.caption).foregroundStyle(.secondary).lineLimit(1)
          }
        }
      }
      Spacer(minLength: 0)
      Text(event.source.type == .atoll ? "Atoll" : "Apple")
        .font(.caption2).foregroundStyle(.secondary)
        .padding(.horizontal, 5).padding(.vertical, 1)
        .background(.quaternary, in: Capsule())
    }
    .padding(.vertical, 2)
  }
}
