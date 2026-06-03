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

  /// Geteilter Store fuer Lesen + Schreiben. `CNContactStore` ist threadsicher
  /// fuer diese Operationen; `nonisolated(unsafe)`, da der Typ nicht `Sendable` ist.
  nonisolated(unsafe) private let store = CNContactStore()

  init(accountId: String = "apple") { self.accountId = accountId }

  /// Schluessel, die Lese- und Schreib-Pfad benoetigen (Mapping liest alle).
  private static let keys: [CNKeyDescriptor] = [
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

  func contacts() async throws -> [UnifiedContact] {
    guard CNContactStore.authorizationStatus(for: .contacts) == .authorized else { return [] }
    return await Task.detached(priority: .utility) { [accountId] in
      Self.fetch(accountId: accountId)
    }.value
  }

  private static func fetch(accountId: String) -> [UnifiedContact] {
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
        out.append(map(c, accountId: accountId))
      }
    } catch {
      return out
    }
    return out
  }

  /// Geteilte CNContact→UnifiedContact-Abbildung (Lesen + Schreiben).
  private static func map(_ c: CNContact, accountId: String) -> UnifiedContact {
    let emails = c.emailAddresses.map { $0.value as String }
    let phones = c.phoneNumbers.map { $0.value.stringValue }
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
    return AppleContactMapper.contact(
      accountId: accountId, identifier: c.identifier,
      givenName: c.givenName, familyName: c.familyName,
      emails: emails, phones: phones,
      kind: kind, organizationName: organizationName,
      addresses: addresses, birthday: birthday
    )
  }

  // MARK: – Schreiben (Phase-7)

  func createContact(_ draft: ContactDraft) async throws -> UnifiedContact {
    let c = CNMutableContact()
    apply(draft, to: c)
    let req = CNSaveRequest()
    req.add(c, toContainerWithIdentifier: nil)
    try store.execute(req)
    return Self.map(c, accountId: accountId)
  }

  func updateContact(id: String, with draft: ContactDraft) async throws -> UnifiedContact {
    let identifier = SourceID.raw(from: id)
    guard let existing = try? store.unifiedContact(withIdentifier: identifier,
                                                   keysToFetch: Self.keys),
          let mutable = existing.mutableCopy() as? CNMutableContact else {
      throw ProviderWriteError.notFound
    }
    apply(draft, to: mutable)
    let req = CNSaveRequest()
    req.update(mutable)
    try store.execute(req)
    return Self.map(mutable, accountId: accountId)
  }

  /// Hard-Delete via `CNSaveRequest.delete` — Apple-Kontakte werden endgueltig entfernt.
  func deleteContact(id: String) async throws {
    let identifier = SourceID.raw(from: id)
    let keys = [CNContactIdentifierKey] as [CNKeyDescriptor]
    guard let existing = try? store.unifiedContact(withIdentifier: identifier, keysToFetch: keys),
          let mutable = existing.mutableCopy() as? CNMutableContact else {
      throw ProviderWriteError.notFound
    }
    let req = CNSaveRequest()
    req.delete(mutable)
    try store.execute(req)
  }

  private func apply(_ d: ContactDraft, to c: CNMutableContact) {
    c.contactType = d.kind == .organization ? .organization : .person
    c.givenName = d.firstName
    c.familyName = d.lastName
    c.organizationName = d.organizationName
    c.emailAddresses = d.emails.map {
      CNLabeledValue(label: CNLabelOther, value: $0 as NSString)
    }
    c.phoneNumbers = d.phones.map {
      CNLabeledValue(label: CNLabelOther, value: CNPhoneNumber(stringValue: $0))
    }
    c.postalAddresses = d.addresses.map { a in
      let p = CNMutablePostalAddress()
      p.street = a.street ?? ""
      p.postalCode = a.postalCode ?? ""
      p.city = a.city ?? ""
      p.state = a.region ?? ""
      p.country = a.country ?? ""
      return CNLabeledValue(label: CNLabelHome, value: p)
    }
    if let b = d.birthday {
      c.birthday = Calendar.current.dateComponents([.year, .month, .day], from: b)
    } else {
      c.birthday = nil
    }
  }
}
