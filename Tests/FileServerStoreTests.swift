// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Sneakers_PAM
import Testing

struct FileServerStoreTests {
    private func makeFolder() -> URL {
        FileManager.default.temporaryDirectory.appending(
            path: "servers-test-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
    }

    private func makeDefaults() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: "servers-legacy-\(UUID().uuidString)"))
    }

    private func sampleList() -> ServerList {
        let entry = ServerEntry(
            id: UUID(),
            url: ServerURL.fixture,
            addedAt: Date(timeIntervalSince1970: 100),
            version: nil
        )
        return ServerList(entries: [entry], activeID: entry.id)
    }

    @Test func startsEmpty() throws {
        let store = try FileServerStore(folder: makeFolder(), legacyDefaults: makeDefaults())
        #expect(store.load() == ServerList())
    }

    @Test func savesAndLoadsTheList() throws {
        let folder = makeFolder()
        let list = sampleList()

        try FileServerStore(folder: folder, legacyDefaults: makeDefaults()).save(list)

        #expect(try FileServerStore(folder: folder, legacyDefaults: makeDefaults()).load() == list)
    }

    @Test func theFileIsExcludedFromBackupsEvenAfterBeingSavedAgain() throws {
        let folder = makeFolder()
        let store = try FileServerStore(folder: folder, legacyDefaults: makeDefaults())

        store.save(sampleList())
        store.save(sampleList())

        let values = try store.fileURL.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(values.isExcludedFromBackup == true)
    }

    @Test func anUnreadableFileLoadsAsEmpty() throws {
        let folder = makeFolder()
        let store = try FileServerStore(folder: folder, legacyDefaults: makeDefaults())
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: store.fileURL)

        #expect(store.load() == ServerList())
    }

    @Test func aListSavedInTheOldDefaultsMovesToTheFileAndLeavesTheDefaults() throws {
        let defaults = try makeDefaults()
        let list = sampleList()
        UserDefaultsServerStore(defaults: defaults).save(list)
        let store = FileServerStore(folder: makeFolder(), legacyDefaults: defaults)

        #expect(store.load() == list)
        #expect(defaults.data(forKey: UserDefaultsServerStore.key) == nil)
        #expect(FileManager.default.fileExists(atPath: store.fileURL.path))
        #expect(store.load() == list)
    }

    @Test func theFileWinsOverAnOldListInTheDefaults() throws {
        let defaults = try makeDefaults()
        UserDefaultsServerStore(defaults: defaults).save(ServerList())
        let store = FileServerStore(folder: makeFolder(), legacyDefaults: defaults)
        let list = sampleList()
        store.save(list)

        #expect(store.load() == list)
    }
}
