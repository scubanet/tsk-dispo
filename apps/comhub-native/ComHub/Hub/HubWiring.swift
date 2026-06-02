import Foundation
import EventKit
import AtollCore
import AtollHub

/// Verdrahtet die konkreten Adapter in den `Hub`. Beim Sign-in aufgerufen mit
/// dem aktuellen User; Atoll-Events brauchen dessen Instructor-id.
enum HubWiring {
  /// Ein gemeinsamer Store fuer den Apple-Kalender-Adapter (Status-Konsistenz
  /// mit `AppleAuthorizationService`). Contacts nutzt einen eigenen Store.
  @MainActor
  static func connectAll(into hub: Hub, currentUser: CurrentUser,
                         eventStore: EKEventStore) {
    hub.reset()

    // Apple/iCloud: Kalender + Erinnerungen + Kontakte.
    let apple = Account(id: "apple", type: .apple, displayName: "iCloud",
                        capabilities: [.calendar, .contacts, .todo])
    hub.connect(AccountConnection(
      account: apple,
      calendar: AppleCalendarAdapter(store: eventStore),
      todo: AppleRemindersAdapter(store: eventStore),
      contacts: AppleContactsAdapter()
    ))

    // Atoll: Events (als CalendarProvider) + Tasks + CRM-Kontakte.
    let atoll = Account(id: "atoll", type: .atoll, displayName: "Atoll",
                        capabilities: [.calendar, .contacts, .todo])
    hub.connect(AccountConnection(
      account: atoll,
      calendar: AtollEventsAdapter(instructorId: currentUser.legacyInstructorId),
      todo: AtollTasksAdapter(),
      contacts: AtollContactsAdapter()
    ))
  }
}
