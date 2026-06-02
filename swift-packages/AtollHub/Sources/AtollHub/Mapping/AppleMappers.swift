import Foundation

/// Uebersetzt aus EventKit extrahierte Roh-Felder in `UnifiedEvent`.
/// Bewusst EventKit-frei (der App-Adapter zieht die Felder aus `EKEvent`),
/// damit die Mapping-Regeln im Paket unit-getestet werden koennen.
public enum AppleEventMapper {
  public static func event(accountId: String, identifier: String, title: String,
                           start: Date, end: Date, isAllDay: Bool,
                           location: String?) -> UnifiedEvent {
    let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    let loc = location?.trimmingCharacters(in: .whitespacesAndNewlines)
    return UnifiedEvent(
      id: "apple:\(identifier)",
      source: AccountRef(accountId: accountId, type: .apple),
      title: cleanTitle.isEmpty ? "(Ohne Titel)" : cleanTitle,
      start: start, end: end, isAllDay: isAllDay,
      location: (loc?.isEmpty ?? true) ? nil : loc
    )
  }
}

/// Uebersetzt aus Contacts.framework extrahierte Roh-Felder in `UnifiedContact`.
public enum AppleContactMapper {
  public static func contact(accountId: String, identifier: String,
                             givenName: String, familyName: String,
                             emails: [String], phones: [String]) -> UnifiedContact {
    UnifiedContact(
      id: "apple:\(identifier)",
      source: AccountRef(accountId: accountId, type: .apple),
      firstName: givenName.trimmingCharacters(in: .whitespacesAndNewlines),
      lastName: familyName.trimmingCharacters(in: .whitespacesAndNewlines),
      emails: emails.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty },
      phones: phones.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
    )
  }
}
