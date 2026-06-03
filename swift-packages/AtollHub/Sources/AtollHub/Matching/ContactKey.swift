import Foundation

/// Normalisiert E-Mail/Telefon zu vergleichbaren Schlüsseln fürs Kontakt-Matching.
/// Bewusst konservativ: ein `nil` heißt „taugt nicht als Matching-Schlüssel".
public enum ContactKey {
  /// Klein + getrimmt; `nil` wenn leer oder kein „x@y"-Muster.
  public static func email(_ raw: String) -> String? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !trimmed.isEmpty else { return nil }
    // Minimaler Plausi-Check: genau ein @, je ein nicht-leerer Teil, Punkt im Domain-Teil.
    let parts = trimmed.split(separator: "@", omittingEmptySubsequences: false)
    guard parts.count == 2, !parts[0].isEmpty, parts[1].contains(".") else { return nil }
    return trimmed
  }

  /// Entfernt alle Nicht-Ziffern; ein führendes `+` bleibt erhalten.
  /// `nil` wenn nach der Bereinigung < 6 Ziffern übrig sind.
  public static func phone(_ raw: String) -> String? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    let hasPlus = trimmed.hasPrefix("+")
    let digits = trimmed.filter { $0.isNumber }
    guard digits.count >= 6 else { return nil }
    return hasPlus ? "+" + digits : digits
  }
}
