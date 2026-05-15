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
}
