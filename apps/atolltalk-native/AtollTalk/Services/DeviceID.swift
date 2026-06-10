import Foundation

/// Stable anonymous install identifier — the Free-tier rate-limit key for the
/// speech proxy. Not a hardware id: regenerated on reinstall (resets the
/// quota, which is acceptable), never tied to the user's identity.
enum DeviceID {
  private static let key = "atoll.device.id"

  static var current: String {
    if let existing = UserDefaults.standard.string(forKey: key) { return existing }
    let fresh = UUID().uuidString.lowercased()
    UserDefaults.standard.set(fresh, forKey: key)
    return fresh
  }
}
