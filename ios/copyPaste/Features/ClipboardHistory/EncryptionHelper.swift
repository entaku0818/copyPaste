import CryptoKit
import Foundation
import Security

enum EncryptionHelper {
    private static let keyService = "com.entaku.clipkit.storageKey"
    private static let keyAccount = "clipboard-encryption-key"

    static func encrypt(_ data: Data) throws -> Data {
        let key = try getOrCreateKey()
        let sealed = try AES.GCM.seal(data, using: key)
        guard let combined = sealed.combined else {
            throw EncryptionError.sealFailed
        }
        return combined
    }

    static func decrypt(_ data: Data) throws -> Data {
        let key = try getOrCreateKey()
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }

    // MARK: - Key management

    private static func getOrCreateKey() throws -> SymmetricKey {
        if let existing = try loadKey() { return existing }
        let key = SymmetricKey(size: .bits256)
        try saveKey(key)
        return key
    }

    private static func loadKey() throws -> SymmetricKey? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keyService,
            kSecAttrAccount as String: keyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        if !SharedConstants.keychainAccessGroup.isEmpty {
            query[kSecAttrAccessGroup as String] = SharedConstants.keychainAccessGroup
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let keyData = result as? Data else { return nil }
            return SymmetricKey(data: keyData)
        case errSecItemNotFound:
            return nil
        default:
            throw EncryptionError.keychainLoadFailed(status)
        }
    }

    private static func saveKey(_ key: SymmetricKey) throws {
        let keyData = key.withUnsafeBytes { Data($0) }
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keyService,
            kSecAttrAccount as String: keyAccount,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        if !SharedConstants.keychainAccessGroup.isEmpty {
            query[kSecAttrAccessGroup as String] = SharedConstants.keychainAccessGroup
        }

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess || status == errSecDuplicateItem else {
            throw EncryptionError.keychainSaveFailed(status)
        }
    }

    // MARK: - Errors

    enum EncryptionError: LocalizedError {
        case sealFailed
        case keychainLoadFailed(OSStatus)
        case keychainSaveFailed(OSStatus)

        var errorDescription: String? {
            switch self {
            case .sealFailed:
                return "AES-GCM seal failed"
            case .keychainLoadFailed(let s):
                return "Keychain load failed: \(s)"
            case .keychainSaveFailed(let s):
                return "Keychain save failed: \(s)"
            }
        }
    }
}
