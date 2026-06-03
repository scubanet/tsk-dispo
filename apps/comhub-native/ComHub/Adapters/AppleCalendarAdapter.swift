import Foundation
@preconcurrency import EventKit
import AtollHub

/// Erfüllt `CalendarProvider` über das System-`EKEventStore`. Liest nur
/// (Phase 1) — Schreiben kommt in Phase 5. Die Berechtigung wird vom
/// `AppleAuthorizationService` (Phase 0) angefragt; hier prüfen wir den Status
/// und liefern bei fehlendem Zugriff eine leere Liste statt zu werfen.
struct AppleCalendarAdapter: CalendarProvider {
  let accountId: String
  private let store: EKEventStore

  init(accountId: String = "apple", store: EKEventStore) {
    self.accountId = accountId
    self.store = store
  }

  func events(in interval: DateInterval) async throws -> [UnifiedEvent] {
    guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return [] }
    let cals = store.calendars(for: .event)
    guard !cals.isEmpty else { return [] }
    let pred = store.predicateForEvents(withStart: interval.start,
                                        end: interval.end, calendars: cals)
    let ekEvents = store.events(matching: pred)
    return ekEvents.map { e in
      AppleEventMapper.event(
        accountId: accountId,
        identifier: e.eventIdentifier ?? "ts-\(e.startDate.timeIntervalSince1970)",
        title: e.title ?? "",
        start: e.startDate, end: e.endDate,
        isAllDay: e.isAllDay, location: e.location,
        calendarId: e.calendar?.calendarIdentifier,
        colorHex: e.calendar?.cgColor.flatMap(Self.hex(from:))
      )
    }
  }

  func createEvent(_ draft: EventDraft) async throws -> UnifiedEvent {
    let e = EKEvent(eventStore: store)
    apply(draft, to: e)
    try store.save(e, span: .thisEvent, commit: true)
    return mapped(e)
  }

  func updateEvent(id: String, with draft: EventDraft) async throws -> UnifiedEvent {
    let identifier = SourceID.raw(from: id)
    guard let e = store.event(withIdentifier: identifier) else { throw ProviderWriteError.notFound }
    apply(draft, to: e)
    try store.save(e, span: .thisEvent, commit: true)
    return mapped(e)
  }

  func deleteEvent(id: String) async throws {
    let identifier = SourceID.raw(from: id)
    guard let e = store.event(withIdentifier: identifier) else { throw ProviderWriteError.notFound }
    try store.remove(e, span: .thisEvent, commit: true)
  }

  private func apply(_ draft: EventDraft, to e: EKEvent) {
    e.title = draft.title
    e.startDate = draft.start
    e.endDate = draft.end
    e.isAllDay = draft.isAllDay
    e.location = draft.location
    if let calId = draft.calendarId, let cal = store.calendar(withIdentifier: calId) {
      e.calendar = cal
    } else if e.calendar == nil {
      e.calendar = store.defaultCalendarForNewEvents
    }
  }

  private func mapped(_ e: EKEvent) -> UnifiedEvent {
    AppleEventMapper.event(
      accountId: accountId,
      identifier: e.eventIdentifier ?? "ts-\(e.startDate.timeIntervalSince1970)",
      title: e.title ?? "", start: e.startDate, end: e.endDate,
      isAllDay: e.isAllDay, location: e.location,
      calendarId: e.calendar?.calendarIdentifier,
      colorHex: e.calendar?.cgColor.flatMap(Self.hex(from:))
    )
  }

  private static func hex(from cg: CGColor) -> String? {
    guard let c = cg.components, c.count >= 3 else { return nil }
    let r = Int((c[0] * 255).rounded()), g = Int((c[1] * 255).rounded()), b = Int((c[2] * 255).rounded())
    return String(format: "#%02X%02X%02X", r, g, b)
  }
}
