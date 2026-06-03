import Foundation

/// Tageszeit-Begruessung. < 11 Morgen, < 17 Tag, sonst Abend.
public enum Greeting {
  public static func phrase(forHour hour: Int) -> String {
    if hour < 11 { return "Guten Morgen" }
    if hour < 17 { return "Guten Tag" }
    return "Guten Abend"
  }
}
