import Foundation
@preconcurrency import Contacts
import AtollHub

/// Erfüllt `ContactsProvider` über `CNContactStore`. Liest Vor-/Nachname,
/// E-Mails, Telefonnummern sowie Firma, Postanschriften, Geburtstag und Typ;
/// mappt via `AppleContactMapper`. Notizen bleiben leer (CNContactNoteKey
/// erfordert ein Sonder-Entitlement). Bei fehlender Berechtigung leere Liste
/// (kein Wurf), damit der Hub die anderen Quellen weiter aggregiert.
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
      CNContactOrganizationNameKey as CNKeyDescriptor,
      CNContactPostalAddressesKey as CNKeyDescriptor,
      CNContactBirthdayKey as CNKeyDescriptor,
      CNContactTypeKey as CNKeyDescriptor,
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
        let organizationName = c.organizationName.isEmpty ? nil : c.organizationName
        let kind: ContactKind = c.contactType == .organization ? .organization : .person
        let addresses = c.postalAddresses.map { lv -> PostalAddress in
          let p = lv.value
          return PostalAddress(
            street: p.street.isEmpty ? nil : p.street,
            postalCode: p.postalCode.isEmpty ? nil : p.postalCode,
            city: p.city.isEmpty ? nil : p.city,
            region: p.state.isEmpty ? nil : p.state,
            country: p.country.isEmpty ? nil : p.country,
            label: lv.label.flatMap { CNLabeledValue<CNPostalAddress>.localizedString(forLabel: $0) }
          )
        }
        // Geburtstag nur uebernehmen, wenn ein vollstaendiges Datum (mit Jahr) vorliegt.
        let birthday: Date? = (c.birthday?.year != nil) ? c.birthday?.date : nil
        out.append(AppleContactMapper.contact(
          accountId: accountId, identifier: c.identifier,
          givenName: c.givenName, familyName: c.familyName,
          emails: emails, phones: phones,
          kind: kind, organizationName: organizationName,
          addresses: addresses, birthday: birthday
        ))
      }
    } catch {
      return out
    }
    return out
  }
}
