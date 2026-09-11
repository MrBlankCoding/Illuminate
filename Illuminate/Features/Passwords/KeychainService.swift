//
//  KeychainService.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/11/26.
//

import Foundation
import Security

protocol KeychainServiceProtocol: Sendable {
    func store(secret: String, for account: String, service: String) throws
    func retrieve(for account: String, service: String) throws -> String?
    func delete(for account: String, service: String) throws
}

enum KeychainError: Error, LocalizedError {
    case unhandledError(status: OSStatus)
    case conversionError

    var errorDescription: String? {
        switch self {
        case .unhandledError(let status):
            if let message = SecCopyErrorMessageString(status, nil) as String? {
                return message
            }
            return "Keychain error with status code: \(status)"
        case .conversionError:
            return "Failed to convert string data to or from UTF-8."
        }
    }
}

final class KeychainService: KeychainServiceProtocol {
    nonisolated static let shared = KeychainService()

    func store(secret: String, for account: String, service: String) throws {
        guard let data = secret.data(using: .utf8) else {
            throw KeychainError.conversionError
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kCFBooleanTrue as Any
        ]

        let attributesToUpdate: [String: Any] = [
            kSecValueData as String: data
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        if updateStatus == errSecItemNotFound {
            var newItem = query
            newItem[kSecValueData as String] = data
            newItem[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

            let addStatus = SecItemAdd(newItem as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unhandledError(status: addStatus)
            }
            return
        }

        throw KeychainError.unhandledError(status: updateStatus)
    }

    func retrieve(for account: String, service: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kCFBooleanTrue as Any,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        var status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            // Fallback check for local non-synchronizable entries
            let fallbackQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]
            status = SecItemCopyMatching(fallbackQuery as CFDictionary, &item)
        }

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }

        guard let data = item as? Data, let secret = String(data: data, encoding: .utf8) else {
            throw KeychainError.conversionError
        }

        return secret
    }

    func delete(for account: String, service: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kCFBooleanTrue as Any
        ]

        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.unhandledError(status: status)
        }

        // Clean up fallback local entry if one existed
        let fallbackQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        _ = SecItemDelete(fallbackQuery as CFDictionary)
    }
}
