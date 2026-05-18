import Foundation
import EventKit
import Observation
import OSLog

/// Wraps `EKEventStore` for SwiftUI. Owns authorisation state, the list of
/// available calendars, event lookup, and CRUD entry points for the editor.
///
/// All mutating methods route through the same store instance so EventKit's
/// `EKEventStoreChanged` notification gets posted to interested observers
/// (DayView / WeekView / MonthView reload on receipt).
@MainActor
@Observable
public final class SystemCalendarStore {
  private let store = EKEventStore()
  private let logger = Logger(subsystem: "swiss.atoll.cal", category: "calendar")

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
      logger.error("requestFullAccessToEvents failed: \(error.localizedDescription, privacy: .public)")
    }
    refreshAuthStatus()
  }

  /// Calendars the user is allowed to mutate (excludes subscribed / read-only).
  public var writableCalendars: [EKCalendar] {
    calendars.filter { $0.allowsContentModifications }
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

  // MARK: - CRUD entry points (used by EventEditorSheet)

  /// Factory for a brand-new EKEvent bound to this store. Caller assigns
  /// `.calendar`, `.title`, `.startDate`, `.endDate` etc. before saving.
  public func makeNewEvent() -> EKEvent {
    EKEvent(eventStore: store)
  }

  /// Persists an event. Defaults to `.thisEvent`; pass `.futureEvents` to edit
  /// a recurrence pattern from this date forward.
  public func save(_ event: EKEvent, span: EKSpan = .thisEvent) throws {
    try store.save(event, span: span, commit: true)
    NotificationCenter.default.post(name: .EKEventStoreChanged, object: store)
  }

  /// Removes an event. Defaults to `.thisEvent`; pass `.futureEvents` to delete
  /// a recurring event and everything after it.
  public func remove(_ event: EKEvent, span: EKSpan = .thisEvent) throws {
    try store.remove(event, span: span, commit: true)
    NotificationCenter.default.post(name: .EKEventStoreChanged, object: store)
  }
}
