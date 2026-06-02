import SwiftUI
import AtollHub

/// Tagesansicht: chronologische Liste der Events des Ankertags.
struct DayColumnView: View {
  let store: CalendarStore

  private var dayEvents: [UnifiedEvent] {
    let day = store.calendar.startOfDay(for: store.anchor)
    return store.eventsByDay[day] ?? []
  }

  var body: some View {
    Group {
      if dayEvents.isEmpty {
        ContentUnavailableView("Keine Termine", systemImage: "calendar")
      } else {
        List(dayEvents) { UnifiedEventRow(event: $0) }
      }
    }
  }
}
