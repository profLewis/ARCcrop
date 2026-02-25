import Foundation
import Security

enum KeychainService {
    private static let serviceName = "com.arccrop.app.credentials"

    // MARK: - Generic key-value storage (like eof-ios)

    static func store(key: String, value: String) {
        let data = Data(value.utf8)
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    static func retrieve(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Provider convenience (wraps generic API)

    static func save(key: String, for provider: APIKeyProvider) -> Bool {
        store(key: provider.credentialKeys.first ?? provider.rawValue, value: key)
        return true
    }

    static func load(for provider: APIKeyProvider) -> String? {
        retrieve(key: provider.credentialKeys.first ?? provider.rawValue)
    }

    static func delete(for provider: APIKeyProvider) -> Bool {
        for k in provider.credentialKeys {
            delete(key: k)
        }
        return true
    }

    static func hasKey(for provider: APIKeyProvider) -> Bool {
        provider.credentialKeys.allSatisfy { key in
            if let val = retrieve(key: key), !val.isEmpty { return true }
            return false
        }
    }
}
