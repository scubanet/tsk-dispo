import Foundation
import Contacts
import SwiftUI
import OSLog

/// Normalised representation of one anniversary entry — the contact's name,
/// the original date (which may carry a year, or only month+day for the
/// "happens every year" case), and a stable identifier we can use as a
/// dedup key when assembling calendar events.
struct ContactAnniversary: Hashable, Sendable, Identifiable {
  let id: String          // CNContact.identifier + "anniversary"
  let contactName: String
  let originalYear: Int?  // nil when the user didn't enter a year
  let month: Int
  let day: Int

  /// Compute the nth-anniversary occurrence within a date interval.
  /// Returns every year of the anniversary that falls inside `range`, with
  /// the *age in years* (i.e. "12. Jahrestag") if `originalYear` is set.
  func occurrences(in range: DateInterval, calendar: Calendar = .current) -> [(date: Date, ageYears: Int?)] {
    var results: [(Date, Int?)] = []
    let startYear = calendar.component(.year, from: range.start)
    let endYear   = calendar.component(.year, from: range.end)
    for year in startYear...endYear {
      var comps = DateComponents()
      comps.year = year
      comps.month = month
      comps.day = day
      guard let date = calendar.date(from: comps) else { continue }
      if range.contains(date) || calendar.isDate(date, inSameDayAs: range.start) {
        let age = originalYear.map { year - $0 }
        results.append((date, age))
      }
    }
    return results
  }
}

/// Observable store for anniversaries fetched from the Contacts framework.
///
/// Apple's EventKit `EKEntityType.event` Birthday calendar (type == .birthday)
/// only mirrors *birthdays*. Anniversaries are stored on `CNContact.dates`
/// with label `CNLabelDateAnniversary` and Apple's own Calendar.app reads
/// them via the Contacts API. We do the same — fetch all contacts that
/// carry an anniversary, expose them as `ContactAnniversary` values, and let
/// the calendar views synthesise yearly all-day events.
///
/// Authorisation: requires `NSContactsUsageDescription` (set in Info.plist)
/// and explicit user consent. Without consent the store stays empty and
/// the rest of the app continues to function normally.
@MainActor
@Observable
final class ContactsAnniversaryStore {
  private let store = CNContactStore()
  private static let logger = Logger(subsystem: "swiss.atoll.cal", category: "contacts")

  /// Current authorisation status for the contacts entity.
  private(set) var authorizationStatus: CNAuthorizationStatus = .notDetermined

  /// All anniversaries found in the user's address book. Empty before the
  /// first refresh, or when the user has denied access.
  private(set) var anniversaries: [ContactAnniversary] = []

  /// Last error from a fetch attempt, for diagnostics.
  private(set) var lastError: Error?

  init() {
    refreshAuthStatus()
  }

  func refreshAuthStatus() {
    authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
  }

  /// Asks the user for permission to read contacts. Safe to call repeatedly;
  /// the system prompt only appears once.
  func requestAccess() async {
    do {
      _ = try await store.requestAccess(for: .contacts)
    } catch {
      Self.logger.error("requestAccess failed: \(error.localizedDescription, privacy: .public)")
    }
    refreshAuthStatus()
  }

  /// Iterate all contacts and collect anniversaries. Cheap enough to run on
  /// app launch and on scenePhase = .active; the contact store is local.
  func refresh() async {
    refreshAuthStatus()
    guard authorizationStatus == .authorized else {
      anniversaries = []
      return
    }

    let result = await Task.detached(priority: .utility) {
      Self.fetchAnniversaries()
    }.value

    switch result {
    case .success(let collected):
      anniversaries = collected
      lastError = nil
      Self.logger.debug("loaded \(collected.count, privacy: .public) anniversaries from Contacts")
    case .failure(let error):
      lastError = error
      Self.logger.error("enumerateContacts failed: \(error.localizedDescription, privacy: .public)")
    }
  }

  /// Off-main-actor fetch. Creates a private `CNContactStore` so nothing
  /// MainActor-isolated needs to cross the isolation boundary.
  nonisolated private static func fetchAnniversaries() -> Result<[ContactAnniversary], Error> {
    let keys: [CNKeyDescriptor] = [
      CNContactGivenNameKey as CNKeyDescriptor,
      CNContactFamilyNameKey as CNKeyDescriptor,
      CNContactNicknameKey as CNKeyDescriptor,
      CNContactDatesKey as CNKeyDescriptor,
      CNContactIdentifierKey as CNKeyDescriptor,
    ]
    let request = CNContactFetchRequest(keysToFetch: keys)
    let store = CNContactStore()
    var collected: [ContactAnniversary] = []
    do {
      try store.enumerateContacts(with: request) { contact, _ in
        // A contact can have multiple labelled dates (anniversary, custom
        // milestones, etc.). We grab the first entry with the canonical
        // anniversary label. CNContact also exposes `.birthday` separately,
        // so we don't accidentally double-count those here.
        for labeledDate in contact.dates {
          guard labeledDate.label == CNLabelDateAnniversary else { continue }
          let comps = labeledDate.value as DateComponents
          guard let m = comps.month, let d = comps.day else { continue }
          let name = displayName(for: contact)
          collected.append(ContactAnniversary(
            id: "\(contact.identifier)#anniversary",
            contactName: name,
            originalYear: comps.year,
            month: m,
            day: d
          ))
          // Only the first anniversary per contact — extending later if
          // someone has multiple meaningful dates is straightforward.
          break
        }
      }
      return .success(collected)
    } catch {
      return .failure(error)
    }
  }

  nonisolated private static func displayName(for contact: CNContact) -> String {
    let nick = contact.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
    if !nick.isEmpty { return nick }
    let parts = [contact.givenName, contact.familyName]
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
    return parts.joined(separator: " ")
  }
}
