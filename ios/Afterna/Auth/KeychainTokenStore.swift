import Foundation
import Security

/// Keychain-backed access token for API + Supabase session.
final class KeychainTokenStore: TokenStore, @unchecked Sendable {
    private let service = "app.afterna.ios.auth"
    private let account = "access_token"
    private let refreshAccount = "refresh_token"
    private let userAccount = "user_id"
    private let lock = NSLock()

    func accessToken() async -> String? {
        lock.lock(); defer { lock.unlock() }
        return read(account: account)
    }

    func save(accessToken: String, refreshToken: String?, userId: String?) {
        lock.lock(); defer { lock.unlock() }
        write(account: account, value: accessToken)
        if let refreshToken {
            write(account: refreshAccount, value: refreshToken)
        }
        if let userId {
            write(account: userAccount, value: userId)
        }
    }

    func clear() {
        lock.lock(); defer { lock.unlock() }
        delete(account: account)
        delete(account: refreshAccount)
        delete(account: userAccount)
    }

    private func read(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func write(account: String, value: String) {
        delete(account: account)
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
