import Foundation

/// Reine, diakritik-/gross-klein-unempfindliche Relevanz-Bewertung fuer die
/// globale Suche. `nil` = kein Treffer; hoeher = relevanter.
public enum SearchRank {
  /// Bewertet, wie gut `haystack` zur `query` passt.
  /// 3 = exakter Prefix, 2 = Wortanfang-Treffer, 1 = enthaelt, nil = kein Treffer.
  public static func score(_ haystack: String, query: String) -> Int? {
    let h = fold(haystack)
    let q = fold(query)
    guard !q.isEmpty else { return nil }
    guard let range = h.range(of: q) else { return nil }
    if range.lowerBound == h.startIndex { return 3 }
    // Wortanfang? (Zeichen davor ist Trenner)
    let before = h.index(before: range.lowerBound)
    if !h[before].isLetter && !h[before].isNumber { return 2 }
    return 1
  }

  /// Bestes Score ueber mehrere Felder (z. B. Name + E-Mail + Telefon).
  public static func best(_ fields: [String?], query: String) -> Int? {
    fields.compactMap { $0 }.compactMap { score($0, query: query) }.max()
  }

  private static func fold(_ s: String) -> String {
    s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
     .trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
