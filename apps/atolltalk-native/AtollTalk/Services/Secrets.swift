import Foundation
import Security

enum SecretKey: String, CaseIterable, Sendable {
  case elevenLabsAPIKey = "swiss.atoll.talk.elevenLabsAPIKey"
  case anthropicAPIKey  = "swiss.atoll.talk.anthropicAPIKey"
}

protocol SecretStore: Sendable {
  func value(for key: SecretKey) -> String?
  func set(_ value: String?, for key: SecretKey)
}

/// Test/double store — no Keychain.
final class InMemorySecretStore: SecretStore, @unchecked Sendable {
  private let lock = NSLock()
  private var dict: [SecretKey: String] = [:]
  func value(for key: SecretKey) -> String? { lock.lock(); defer { lock.unlock() }; return dict[key] }
  func set(_ value: String?, for key: SecretKey) {
    lock.lock(); defer { lock.unlock() }
    if let value { dict[key] = value } else { dict[key] = nil }
  }
}

/// Production store — iOS Keychain (generic password, this app only).
final class KeychainSecretStore: SecretStore, @unchecked Sendable {
  func value(for key: SecretKey) -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: key.rawValue,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
          let data = item as? Data,
          let str = String(data: data, encoding: .utf8) else { return nil }
    return str
  }

  func set(_ value: String?, for key: SecretKey) {
    let base: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: key.rawValue,
    ]
    SecItemDelete(base as CFDictionary)
    guard let value, let data = value.data(using: .utf8) else { return }
    var add = base
    add[kSecValueData as String] = data
    add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
    SecItemAdd(add as CFDictionary, nil)
  }
}
