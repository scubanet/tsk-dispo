import Foundation

/// Deterministischer Palettenindex aus einem Namen (gleicher String -> gleicher
/// Index). Spiegelt die Hash-Logik des Mockups (`h = h*31 + char`).
public enum AvatarPalette {
  public static func index(for name: String, count: Int) -> Int {
    guard count > 0 else { return 0 }
    var h: UInt32 = 0
    for scalar in name.unicodeScalars {
      h = h &* 31 &+ scalar.value
    }
    return Int(h % UInt32(count))
  }
}
