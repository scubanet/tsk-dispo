import Foundation
import Observation
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

  func reload(using hub: Hub) async {
    loading = true
    let all = await hub.allContacts()
    let groups = ContactMatcher.group(all)
    merged = groups.map(MergedContact.init(group:))
      .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    errors = hub.lastErrors
    loading = false
  }
}
