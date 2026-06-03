import SwiftUI
import AtollHub

/// Formular zum Erstellen/Bearbeiten eines Kontakts. Baut einen `ContactDraft`
/// aus lokalem State und liefert ihn samt gewaehlter Quelle ueber `onSave`.
struct ContactEditSheet: View {
  let existing: MergedContact?         // nil → erstellen
  let onSave: (ContactDraft, AccountType) -> Void
  @Environment(\.dismiss) private var dismiss

  @State private var kind: ContactKind = .person
  @State private var firstName = ""
  @State private var lastName = ""
  @State private var organizationName = ""
  @State private var emails: [String] = [""]
  @State private var phones: [String] = [""]
  @State private var street = ""
  @State private var postalCode = ""
  @State private var city = ""
  @State private var country = ""
  @State private var hasBirthday = false
  @State private var birthday = Date()
  @State private var notes = ""
  @State private var source: AccountType = .atoll    // nur beim Erstellen

  private var draft: ContactDraft {
    let addr = (street.isEmpty && postalCode.isEmpty && city.isEmpty && country.isEmpty)
      ? []
      : [PostalAddress(street: street.nilIfEmpty, postalCode: postalCode.nilIfEmpty,
                       city: city.nilIfEmpty, country: country.nilIfEmpty)]
    return ContactDraft(
      kind: kind, firstName: firstName, lastName: lastName,
      organizationName: organizationName,
      emails: emails.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty },
      phones: phones.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty },
      addresses: addr, birthday: hasBirthday ? birthday : nil, notes: notes)
  }

  var body: some View {
    NavigationStack {
      Form {
        if existing == nil {
          Picker("Quelle", selection: $source) {
            Text("Atoll").tag(AccountType.atoll)
            Text("Apple").tag(AccountType.apple)
          }
        }
        Picker("Typ", selection: $kind) {
          Text("Person").tag(ContactKind.person)
          Text("Firma").tag(ContactKind.organization)
        }
        if kind == .person {
          TextField("Vorname", text: $firstName)
          TextField("Nachname", text: $lastName)
        } else {
          TextField("Firmenname", text: $organizationName)
        }
        Section("E-Mail") {
          ForEach(emails.indices, id: \.self) { i in
            TextField("E-Mail", text: $emails[i])
          }
          Button("E-Mail hinzufügen") { emails.append("") }
        }
        Section("Telefon") {
          ForEach(phones.indices, id: \.self) { i in
            TextField("Telefon", text: $phones[i])
          }
          Button("Telefon hinzufügen") { phones.append("") }
        }
        Section("Adresse") {
          TextField("Strasse", text: $street)
          TextField("PLZ", text: $postalCode)
          TextField("Ort", text: $city)
          TextField("Land", text: $country)
        }
        Section {
          Toggle("Geburtstag", isOn: $hasBirthday)
          if hasBirthday {
            DatePicker("Datum", selection: $birthday, displayedComponents: .date)
          }
        }
        Section("Notizen") {
          TextField("Notizen", text: $notes, axis: .vertical)
        }
      }
      .navigationTitle(existing == nil ? "Neuer Kontakt" : "Kontakt bearbeiten")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Abbrechen") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Sichern") { onSave(draft, source); dismiss() }
            .disabled(!draft.isValid)
        }
      }
      .onAppear(perform: prefill)
    }
    #if os(macOS)
    .frame(minWidth: 480, minHeight: 560)
    #endif
  }

  private func prefill() {
    guard let c = existing else { return }
    kind = c.kind
    firstName = c.firstName ?? ""
    lastName = c.lastName ?? ""
    organizationName = c.organizationName ?? ""
    emails = c.emails.isEmpty ? [""] : c.emails
    phones = c.phones.isEmpty ? [""] : c.phones
    if let a = c.addresses.first {
      street = a.street ?? ""
      postalCode = a.postalCode ?? ""
      city = a.city ?? ""
      country = a.country ?? ""
    }
    if let b = c.birthday { hasBirthday = true; birthday = b }
    notes = c.notes ?? ""
    // Quelle beim Bearbeiten = bevorzugt Atoll-Member, sonst Apple.
    source = (c.members.first { $0.source.type == .atoll } ?? c.members.first)?.source.type ?? .atoll
  }
}

private extension String {
  var nilIfEmpty: String? { isEmpty ? nil : self }
}
