import Foundation
import Security

// ═══════════════════════════════════════
// MARK: - Keychain Helper
// ═══════════════════════════════════════
//
// Thin wrapper around the Security framework. We store:
//
//   • appleUserID        — the stable ASAuthorizationAppleIDCredential.user
//   • appleUserEmail     — the user's email (real or private-relay)
//   • appleUserFullName  — "First Last" (only provided on first sign-in!)
//
// Items are scoped to this app via kSecAttrService. We use
// kSecAttrAccessibleAfterFirstUnlock so the values survive reboots but stay
// inside Apple's secure storage.
//
enum KeychainHelper {
    enum Key: String {
        case appleUserID       = "divelogpro.apple.userID"
        case appleUserEmail    = "divelogpro.apple.email"
        case appleUserFullName = "divelogpro.apple.fullName"
    }

    private static let service = "com.weckherlin.DiveLogPro.auth"

    // ── Save ────────────────────────────────────

    @discardableResult
    static func save(_ value: String, forKey key: Key) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        // Delete existing item (if any) so we cleanly overwrite.
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      service,
            kSecAttrAccount as String:      key.rawValue,
            kSecAttrAccessible as String:   kSecAttrAccessibleAfterFirstUnlock,
            kSecValueData as String:        data,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    // ── Read ────────────────────────────────────

    static func read(key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      service,
            kSecAttrAccount as String:      key.rawValue,
            kSecReturnData as String:       true,
            kSecMatchLimit as String:       kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let string = String(data: data, encoding: .utf8)
        else { return nil }

        return string
    }

    // ── Delete ──────────────────────────────────

    @discardableResult
    static func delete(key: Key) -> Bool {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Wipes every auth-related value. Used on sign-out / account delete.
    static func wipeAuth() {
        delete(key: .appleUserID)
        delete(key: .appleUserEmail)
        delete(key: .appleUserFullName)
    }
}
