import Foundation
import Observation
import EventKit
import Contacts

/// Vereinheitlichter Berechtigungs-Status pro Apple-Datenquelle.
enum CapabilityAuthorization: Sendable {
  case notDetermined, authorized, denied, restricted
}

@MainActor
@Observable
final class AppleAuthorizationService {
  private(set) var calendars: CapabilityAuthorization = .notDetermined
  private(set) var reminders: CapabilityAuthorization = .notDetermined
  private(set) var contacts: CapabilityAuthorization = .notDetermined

  private let eventStore = EKEventStore()
  private let contactStore = CNContactStore()

  /// Beim App-Start aufrufen: fragt alle drei Berechtigungen an und merkt sich den Status.
  func requestAll() async {
    calendars = await mapEvent { try await eventStore.requestFullAccessToEvents() }
    reminders = await mapEvent { try await eventStore.requestFullAccessToReminders() }
    contacts  = await requestContacts()
  }

  func refreshStatus() {
    calendars = Self.map(EKEventStore.authorizationStatus(for: .event))
    reminders = Self.map(EKEventStore.authorizationStatus(for: .reminder))
    contacts  = Self.map(CNContactStore.authorizationStatus(for: .contacts))
  }

  // MARK: – Helpers

  private func mapEvent(_ request: () async throws -> Bool) async -> CapabilityAuthorization {
    do { return try await request() ? .authorized : .denied }
    catch { return .denied }
  }

  private func requestContacts() async -> CapabilityAuthorization {
    await withCheckedContinuation { continuation in
      contactStore.requestAccess(for: .contacts) { granted, _ in
        continuation.resume(returning: granted ? .authorized : .denied)
      }
    }
  }

  private static func map(_ status: EKAuthorizationStatus) -> CapabilityAuthorization {
    // `default` statt explizitem (deprecated) `.authorized` — vermeidet
    // Compile-Risiko, falls das Symbol auf dem SDK entfällt; `.fullAccess`
    // und `.writeOnly` sind das aktuelle „darf lesen/schreiben".
    switch status {
    case .fullAccess, .writeOnly: return .authorized
    case .denied:        return .denied
    case .restricted:    return .restricted
    case .notDetermined: return .notDetermined
    default:             return .notDetermined
    }
  }

  private static func map(_ status: CNAuthorizationStatus) -> CapabilityAuthorization {
    switch status {
    case .authorized:    return .authorized
    case .denied:        return .denied
    case .restricted:    return .restricted
    case .notDetermined: return .notDetermined
    default:             return .authorized  // .limited (neuere SDKs) zählt als Zugriff
    }
  }
}
