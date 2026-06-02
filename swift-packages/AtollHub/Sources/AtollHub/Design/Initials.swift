import Foundation

/// Initialen aus einem Namen: erster + letzter Buchstabe; ein Wort -> erste zwei;
/// leer/ohne Buchstaben -> "?". Nicht-Buchstaben werden ignoriert.
/// Tokens in Klammern (z. B. "(GmbH)") werden uebersprungen.
public enum Initials {
  public static func from(_ name: String) -> String {
    let parts = name
      .components(separatedBy: .whitespaces)
      .filter { w in
        guard let first = w.unicodeScalars.first else { return false }
        return CharacterSet.letters.contains(first)
      }
      .map { w in
        String(w.unicodeScalars.filter { CharacterSet.letters.contains($0) })
      }
      .filter { !$0.isEmpty }
    guard let first = parts.first else { return "?" }
    if parts.count == 1 {
      return String(first.prefix(2)).uppercased()
    }
    let last = parts[parts.count - 1]
    return (String(first.prefix(1)) + String(last.prefix(1))).uppercased()
  }
}
