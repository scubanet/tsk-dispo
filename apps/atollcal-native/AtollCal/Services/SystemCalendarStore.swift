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
      // Apple's high-level API returns most calendars but, on some iOS
      // versions, omits the iCloud "Geburtstage / Birthdays" calendar
      // (`EKCalendar.type == .birthday`). That calendar also holds
      // *Jahrestage* (anniversaries) — when it's missing, the user can't
      // toggle birthdays/anniversaries in the source picker and they never
      // surface in the agenda.
      //
      // Sweep every `EKSource` (iCloud, Local, Google, Birthdays-source)
      // and merge in anything the high-level call missed. Dedupe by
      // `calendarIdentifier` so we never double-count.
      var found = store.calendars(for: .event)
      var knownIds = Set(found.map { $0.calendarIdentifier })
      for source in store.sources {
        for cal in source.calendars(for: .event) where !knownIds.contains(cal.calendarIdentifier) {
          found.append(cal)
          knownIds.insert(cal.calendarIdentifier)
        }
      }
      calendars = found
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

  /// Looks up an EKEvent by its persistent identifier. Used by drag-and-drop
  /// to resolve a drag payload (which carries just the identifier) back to
  /// the live event before mutating it.
  public func event(withIdentifier identifier: String) -> EKEvent? {
    store.event(withIdentifier: identifier)
  }

  /// Reschedules an event to `newStart`, preserving its duration. Always uses
  /// `span: .thisEvent` so recurring patterns only move the dragged instance.
  ///
  /// When an `undoManager` is supplied, the inverse reschedule is registered
  /// so ⌘Z restores the previous start. Because the undo handler calls
  /// `reschedule` recursively (with the *current* `undoManager`), redo works
  /// automatically — `UndoManager` flips the stack while undoing, so the
  /// "new" registration becomes the redo entry.
  public func reschedule(_ event: EKEvent, to newStart: Date, undoManager: UndoManager? = nil) throws {
    guard let oldStart = event.startDate as Date?,
          let oldEnd = event.endDate as Date? else { return }
    let identifier = event.eventIdentifier
    let duration = oldEnd.timeIntervalSince(oldStart)
    event.startDate = newStart
    event.endDate = newStart.addingTimeInterval(duration)
    try save(event, span: .thisEvent)

    guard let undoManager, let identifier else { return }
    undoManager.registerUndo(withTarget: self) { store in
      MainActor.assumeIsolated {
        guard let ek = store.event(withIdentifier: identifier) else { return }
        try? store.reschedule(ek, to: oldStart, undoManager: undoManager)
      }
    }
    undoManager.setActionName(String(localized: "Termin verschieben"))
  }
}
