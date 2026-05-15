import Foundation
import EventKit
import Observation

@MainActor
@Observable
public final class SystemCalendarStore {
  private let store = EKEventStore()

  public private(set) var authorizationStatus: EKAuthorizationStatus = .notDetermined
  public private(set) var calendars: [EKCalendar] = []

  public init() {
    refreshAuthStatus()
  }

  public func refreshAuthStatus() {
    authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    if authorizationStatus == .fullAccess {
      calendars = store.calendars(for: .event)
    }
  }

  public func requestAccess() async {
    do {
      try await store.requestFullAccessToEvents()
    } catch {
      // status auf denied wird vom System gesetzt
    }
    refreshAuthStatus()
  }

  /// Liefert alle EKEvents im Range, gefiltert nach den angegebenen Calendar-Ids.
  /// Wenn calendarIds nil oder leer: ALLE Events aus erlaubten Kalendern.
  public func events(in range: DateInterval, calendarIds: Set<String>? = nil) -> [EKEvent] {
    guard authorizationStatus == .fullAccess else { return [] }
    let cals: [EKCalendar]
    if let ids = calendarIds, !ids.isEmpty {
      cals = calendars.filter { ids.contains($0.calendarIdentifier) }
    } else {
      cals = calendars
    }
    guard !cals.isEmpty else { return [] }
    let pred = store.predicateForEvents(withStart: range.start, end: range.end, calendars: cals)
    return store.events(matching: pred)
  }

  /// Subscribe für externe EKEvent-Änderungen — z.B. wenn iCloud syncted.
  /// Caller hält den zurückgegebenen Token solange er benachrichtigt werden will.
  public func observeChanges(handler: @escaping () -> Void) -> NSObjectProtocol {
    NotificationCenter.default.addObserver(
      forName: .EKEventStoreChanged,
      object: store,
      queue: .main,
      using: { _ in handler() }
    )
  }
}
