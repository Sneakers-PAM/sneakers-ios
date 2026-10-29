// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Security
@testable import Sneakers_PAM
import Testing

struct KeychainSessionStoreTests {
    private func makeStore() -> (store: KeychainSessionStore, service: String) {
        let service = "sneakers-test-\(UUID().uuidString)"
        return (KeychainSessionStore(service: service), service)
    }

    @Test func startsEmpty() {
        let (store, _) = makeStore()
        #expect(store.load(for: UUID()) == nil)
    }

    @Test func savesAndLoadsASession() {
        let (store, _) = makeStore()
        let id = UUID()
        let session = AuthenticatedSession(cookieValue: "c", csrfToken: "t", userID: "u", setupRecommended: true)

        store.save(session, for: id)

        #expect(store.load(for: id) == session)
        store.delete(for: id)
    }

    @Test func savingAgainReplacesTheSession() {
        let (store, _) = makeStore()
        let id = UUID()
        store.save(.fixture(csrf: "old"), for: id)
        store.save(.fixture(csrf: "new"), for: id)

        #expect(store.load(for: id)?.csrfToken == "new")
        store.delete(for: id)
    }

    @Test func eachServerHasItsOwnSession() {
        let (store, _) = makeStore()
        let first = UUID()
        let second = UUID()
        store.save(.fixture(cookie: "one"), for: first)
        store.save(.fixture(cookie: "two"), for: second)

        #expect(store.load(for: first)?.cookieValue == "one")
        #expect(store.load(for: second)?.cookieValue == "two")
        store.delete(for: first)
        #expect(store.load(for: first) == nil)
        #expect(store.load(for: second)?.cookieValue == "two")
        store.delete(for: second)
    }

    @Test func deletingWhatIsNotThereIsHarmless() {
        let (store, _) = makeStore()
        store.delete(for: UUID())
    }

    @Test func theItemStaysOnThisDeviceAndOutOfICloud() throws {
        let (store, service) = makeStore()
        let id = UUID()
        store.save(.fixture(), for: id)
        defer { store.delete(for: id) }

        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword]
        query[kSecAttrService as String] = service
        query[kSecAttrAccount as String] = id.uuidString
        query[kSecAttrSynchronizable as String] = kSecAttrSynchronizableAny
        query[kSecReturnAttributes as String] = true
        var result: CFTypeRef?
        #expect(SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess)
        let attributes = try #require(result as? [String: Any])

        #expect(attributes[kSecAttrAccessible as String] as? String ==
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
        let synchronizable = attributes[kSecAttrSynchronizable as String] as? Bool ?? false
        #expect(synchronizable == false)
    }
}
