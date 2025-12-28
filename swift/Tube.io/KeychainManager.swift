//
//  KeychainManager.swift
//  Tube.io
//
//  Created by Léo Combaret on 27/12/2025.
//

import Foundation
import Security

/// Manages Keychain storage for data that must persist across app reinstalls
final class KeychainManager {
    static let shared = KeychainManager()

    private let service = "com.tubeio.app"

    private init() {}

    // MARK: - Keys
    enum Key: String {
        case trialStartDate = "trial_start_date"
        case hasUsedTrial = "has_used_trial"
    }

    // MARK: - Save Data

    func save(_ data: Data, forKey key: Key) -> Bool {
        // Delete any existing item first
        delete(forKey: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    func save(_ string: String, forKey key: Key) -> Bool {
        guard let data = string.data(using: .utf8) else { return false }
        return save(data, forKey: key)
    }

    func save(_ date: Date, forKey key: Key) -> Bool {
        let timestamp = String(date.timeIntervalSince1970)
        return save(timestamp, forKey: key)
    }

    func save(_ bool: Bool, forKey key: Key) -> Bool {
        return save(bool ? "true" : "false", forKey: key)
    }

    // MARK: - Read Data

    func getData(forKey key: Key) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    func getString(forKey key: Key) -> String? {
        guard let data = getData(forKey: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func getDate(forKey key: Key) -> Date? {
        guard let string = getString(forKey: key),
              let timestamp = Double(string) else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    func getBool(forKey key: Key) -> Bool {
        return getString(forKey: key) == "true"
    }

    // MARK: - Delete Data

    @discardableResult
    func delete(forKey key: Key) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
