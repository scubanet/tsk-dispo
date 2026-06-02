/// Typ eines angebundenen Kontos.
public enum AccountType: String, Sendable, CaseIterable {
  case apple
  case google
  case microsoft
  case atoll
}

/// Fähigkeit, die ein Konto liefern kann.
public enum Capability: String, Sendable, CaseIterable {
  case mail
  case calendar
  case todo
  case contacts
  case comms      // Atoll: Kombox (WhatsApp + Mail pro Kontakt)
  case events     // Atoll: Atoll-Events
  case cardInbox  // Atoll: card_leads
}
