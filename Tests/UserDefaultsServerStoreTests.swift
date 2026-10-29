// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Sneakers_PAM
import Testing

struct UserDefaultsServerStoreTests {
    private func makeDefaults() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: "servers-test-\(UUID().uuidString)"))
    }

    @Test func startsEmpty() throws {
        let store = try UserDefaultsServerStore(defaults: makeDefaults())
        #expect(store.load() == ServerList())
    }

    @Test func savesAndLoadsTheList() throws {
        let defaults = try makeDefaults()
        let entry = try ServerEntry(
            id: UUID(),
            url: ServerURL(input: "one.example.org"),
            addedAt: Date(timeIntervalSince1970: 100)
        )
        let list = ServerList(entries: [entry], activeID: entry.id)

        UserDefaultsServerStore(defaults: defaults).save(list)

        #expect(UserDefaultsServerStore(defaults: defaults).load() == list)
    }

    @Test func anUnreadableValueLoadsAsEmpty() throws {
        let defaults = try makeDefaults()
        defaults.set(Data("not json".utf8), forKey: UserDefaultsServerStore.key)

        #expect(UserDefaultsServerStore(defaults: defaults).load() == ServerList())
    }
}
