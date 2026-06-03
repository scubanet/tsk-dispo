import Foundation
import Observation
import Contacts
import AtollHub

/// Laedt + matcht das kombinierte Adressbuch (Apple + Atoll) ueber den Hub.
@MainActor
@Observable
final class ContactsStore {
  private(set) var merged: [MergedContact] = []
  private(set) var loading = false
  private(set) var errors: [String] = []
  var search = ""

  var filtered: [MergedContact] {
    let q = search.trimmingCharacters(in: .whitespaces).lowercased()
    guard !q.isEmpty else { return merged }
    return merged.filter { c in
      c.displayName.lowercased().contains(q)
        || c.emails.contains { $0.lowercased().contains(q) }
        || c.phones.contains { $0.contains(q) }
    }
  }

  private nonisolated(unsafe) var changeObserver: NSObjectProtocol?

  /// Reagiert auf System-Aenderungen (Contacts) und laedt neu. Idempotent.
  func startObservingChanges(using hub: Hub) {
    guard changeObserver == nil else { return }
    changeObserver = NotificationCenter.default.addObserver(
      forName: .CNContactStoreDidChange, object: nil, queue: .main
    ) { [weak self] _ in
      Task { @MainActor in await self?.reload(using: hub) }
    }
  }

  deinit {
    if let changeObserver { NotificationCenter.default.removeObserver(changeObserver) }
  }

  func reload(using hub: Hub) async {
    loading = true
    let all = await hub.allContacts()
    let groups = ContactMatcher.group(all)
    merged = groups.map(MergedContact.init(group:))
      .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    errors = hub.lastErrors
    loading = false
  }

  /// Legt einen Kontakt in der gewaehlten Quelle an und laedt neu.
  @discardableResult
  func create(_ draft: ContactDraft, source: AccountType, using hub: Hub) async -> Bool {
    do {
      _ = try await hub.createContact(draft, source: source)
      await reload(using: hub)
      return true
    } catch {
      errors.append(String(describing: error))
      return false
    }
  }

  /// Aktualisiert einen Kontakt (id-Praefix apple:/atoll: steuert das Routing) und laedt neu.
  @discardableResult
  func update(id: String, with draft: ContactDraft, using hub: Hub) async -> Bool {
    do {
      _ = try await hub.updateContact(id: id, with: draft)
      await reload(using: hub)
      return true
    } catch {
      errors.append(String(describing: error))
      return false
    }
  }

  /// Loescht/archiviert einen Kontakt (id-Praefix apple:/atoll: steuert das Routing) und laedt neu.
  @discardableResult
  func delete(id: String, using hub: Hub) async -> Bool {
    do {
      try await hub.deleteContact(id: id)
      await reload(using: hub)
      return true
    } catch {
      errors.append(String(describing: error))
      return false
    }
  }
}
