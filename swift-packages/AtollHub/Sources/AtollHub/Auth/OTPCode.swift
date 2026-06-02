/// Reiner Validierungs-Helfer für den 6-stelligen E-Mail-OTP-Code.
public enum OTPCode {
  public static let length = 6

  /// Nur Ziffern behalten (Leerzeichen/Bindestriche aus Paste entfernen).
  public static func sanitize(_ raw: String) -> String {
    String(raw.filter { $0.isNumber })
  }

  /// Genau `length` Ziffern.
  public static func isValid(_ raw: String) -> Bool {
    let s = sanitize(raw)
    return s.count == length && s.allSatisfy { $0.isNumber }
  }
}
