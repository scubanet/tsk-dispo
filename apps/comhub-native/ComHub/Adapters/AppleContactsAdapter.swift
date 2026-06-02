import Foundation
import Contacts
import AtollHub

/// Erfüllt `ContactsProvider` über `CNContactStore`. Liest Vor-/Nachname,
/// E-Mails und Telefonnummern; mappt via `AppleContactMapper`. Bei fehlender
/// Berechtigung leere Liste (kein Wurf), damit der Hub die anderen Quellen
/// weiter aggregiert.
struct AppleContactsAdapter: ContactsProvider {
  let accountId: String

  init(accountId: String = "apple") { self.accountId = accountId }

  func contacts() async throws -> [UnifiedContact] {
    guard CNContactStore.authorizationStatus(for: .contacts) == .authorized else { return [] }
    return await Task.detached(priority: .utility) { [accountId] in
      Self.fetch(accountId: accountId)
    }.value
  }

  private static func fetch(accountId: String) -> [UnifiedContact] {
    let keys: [CNKeyDescriptor] = [
      CNContactGivenNameKey as CNKeyDescriptor,
      CNContactFamilyNameKey as CNKeyDescriptor,
      CNContactEmailAddressesKey as CNKeyDescriptor,
      CNContactPhoneNumbersKey as CNKeyDescriptor,
      CNContactIdentifierKey as CNKeyDescriptor,
    ]
    let request = CNContactFetchRequest(keysToFetch: keys)
    let store = CNContactStore()
    var out: [UnifiedContact] = []
    do {
      try store.enumerateContacts(with: request) { c, _ in
        let emails = c.emailAddresses.map { $0.value as String }
        let phones = c.phoneNumbers.map { $0.value.stringValue }
        // Namenlose Kontakte ohne jede Kontaktinfo überspringen.
        let hasName = !(c.givenName + c.familyName).trimmingCharacters(in: .whitespaces).isEmpty
        guard hasName || !emails.isEmpty || !phones.isEmpty else { return }
        out.append(AppleContactMapper.contact(
          accountId: accountId, identifier: c.identifier,
          givenName: c.givenName, familyName: c.familyName,
          emails: emails, phones: phones
        ))
      }
    } catch {
      return out
    }
    return out
  }
}
