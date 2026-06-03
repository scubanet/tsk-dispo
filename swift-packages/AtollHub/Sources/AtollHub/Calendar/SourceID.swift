import Foundation

/// Trennt das Quell-Praefix (`apple:` / `atoll:`) von der rohen Anbieter-Id ab,
/// die `UnifiedEvent`/`UnifiedTask` in ihrer `id` tragen.
public enum SourceID {
  /// Liefert alles nach dem ERSTEN Doppelpunkt; ohne Doppelpunkt den ganzen String.
  public static func raw(from id: String) -> String {
    guard let i = id.firstIndex(of: ":") else { return id }
    return String(id[id.index(after: i)...])
  }
}
