// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import os
import Security

/// Keeps each server's session in the Keychain, on this device only. The items are never synced to iCloud and are
/// readable only while the device is unlocked, so nothing about a session leaves the device or an Apple account.
nonisolated struct KeychainSessionStore: SessionStoring {
    private static let logger = Logger(subsystem: "com.therabbithole.app.apple.sneakers-pam", category: "auth")
    static let defaultService = "com.therabbithole.app.apple.sneakers-pam.session"

    var service = KeychainSessionStore.defaultService

    func load(for serverID: UUID) -> AuthenticatedSession? {
        var query = baseQuery(for: serverID)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            if status != errSecItemNotFound {
                Self.logger.error("keychain read failed: \(status)")
            }
            return nil
        }
        return try? JSONDecoder().decode(AuthenticatedSession.self, from: data)
    }

    func save(_ session: AuthenticatedSession, for serverID: UUID) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        let query = baseQuery(for: serverID)
        let update: [String: Any] = [kSecValueData as String: data]

        let updated = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if updated == errSecSuccess {
            return
        }
        guard updated == errSecItemNotFound else {
            Self.logger.error("keychain update failed: \(updated)")
            return
        }

        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let added = SecItemAdd(add as CFDictionary, nil)
        if added != errSecSuccess {
            Self.logger.error("keychain add failed: \(added)")
        }
    }

    func delete(for serverID: UUID) {
        let status = SecItemDelete(baseQuery(for: serverID) as CFDictionary)
        if status != errSecSuccess, status != errSecItemNotFound {
            Self.logger.error("keychain delete failed: \(status)")
        }
    }

    private func baseQuery(for serverID: UUID) -> [String: Any] {
        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword]
        query[kSecAttrService as String] = service
        query[kSecAttrAccount as String] = serverID.uuidString
        query[kSecAttrSynchronizable as String] = false
        return query
    }
}
