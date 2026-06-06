import Foundation

/// One glossary mapping for a language pair. `a` is the term in the
/// lexicographically-smaller language code, `b` in the larger — so storage is
/// order-independent (see `GlossaryStore.sortedLangs`).
struct GlossaryEntry: Codable, Identifiable, Equatable, Sendable {
  var id: UUID = UUID()
  var a: String
  var b: String
}
