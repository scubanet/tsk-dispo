import Foundation

/// Gruppiert Kontakte verschiedener Quellen, die über einen gemeinsamen
/// normalisierten E-Mail-/Telefon-Schlüssel zusammengehören (Union-Find).
/// Kontakte ohne brauchbaren Schlüssel bleiben Einzelgruppen.
public enum ContactMatcher {
  public static func group(_ contacts: [UnifiedContact]) -> [[UnifiedContact]] {
    var parent = Array(0..<contacts.count)

    func find(_ i: Int) -> Int {
      var root = i
      while parent[root] != root { root = parent[root] }
      var cur = i
      while parent[cur] != root { let next = parent[cur]; parent[cur] = root; cur = next }
      return root
    }
    func union(_ a: Int, _ b: Int) { parent[find(a)] = find(b) }

    // Schlüssel → erster Index, der ihn gesehen hat.
    var keyToIndex: [String: Int] = [:]
    for (i, c) in contacts.enumerated() {
      let keys = c.emails.compactMap(ContactKey.email) + c.phones.compactMap(ContactKey.phone)
      for key in keys {
        if let seen = keyToIndex[key] { union(i, seen) } else { keyToIndex[key] = i }
      }
    }

    // Indizes nach Wurzel bündeln, Eingabereihenfolge erhalten.
    var buckets: [Int: [UnifiedContact]] = [:]
    var order: [Int] = []
    for (i, c) in contacts.enumerated() {
      let root = find(i)
      if buckets[root] == nil { order.append(root) }
      buckets[root, default: []].append(c)
    }
    return order.map { buckets[$0]! }
  }
}
