import SwiftUI

/// Visuelle Repräsentation eines CalendarEvent als Bar/Card auf der Zeitachse.
/// Width + Height + Position berechnet der Caller.
struct EventBar: View {
  let event: CalendarEvent
  var compact: Bool = false  // für WeekView/MonthView dichteres Layout

  var body: some View {
    HStack(alignment: .top, spacing: 6) {
      Rectangle()
        .fill(event.color)
        .frame(width: 3)

      VStack(alignment: .leading, spacing: 2) {
        Text(event.title)
          .font(compact ? .caption2 : .caption)
          .lineLimit(compact ? 1 : 2)
        if !compact, let loc = event.location, !loc.isEmpty {
          Text(loc)
            .font(.caption2)
            .foregroundColor(.secondary)
            .lineLimit(1)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.vertical, 3)
    .padding(.horizontal, 4)
    .background(event.color.opacity(0.15))
    .cornerRadius(4)
  }
}
