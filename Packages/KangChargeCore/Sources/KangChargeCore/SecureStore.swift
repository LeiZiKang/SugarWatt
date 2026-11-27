import Foundation
import Security

/// Lightweight Keychain wrapper shared by macOS, iOS, watchOS and their widgets.
/// Stores the personal MCP address (which embeds device serial and access token) securely.
public enum SecureStore {
    private static let service = "KangCharge"

    private static func baseQuery(_ key: String, accessGroup: String?) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        if let accessGroup { query[kSecAttrAccessGroup as String] = accessGroup }
        return query
    }

    public static func string(forKey key: String) -> String? {
        for group in candidateGroups {
            var query = baseQuery(key, accessGroup: group)
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne
            var result: AnyObject?
            if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
               let data = result as? Data, let value = String(data: data, encoding: .utf8) {
                return value
            }
        }
        return nil
    }

    public static func set(_ value: String?, forKey key: String) {
        for group in candidateGroups {
            SecItemDelete(baseQuery(key, accessGroup: group) as CFDictionary)
        }
        guard let value, !value.isEmpty else { return }
        for group in candidateGroups {
            var query = baseQuery(key, accessGroup: group)
            query[kSecValueData as String] = Data(value.utf8)
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            if SecItemAdd(query as CFDictionary, nil) == errSecSuccess { return }
        }
    }

    /// Shared App Group first; fall back to the app's own keychain when unsigned / no App Group.
    private static var candidateGroups: [String?] {
        AppConfig.appGroup.map { [$0, nil] } ?? [nil]
    }
}
