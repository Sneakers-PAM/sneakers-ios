// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import os

/// Keeps the server list in a file in Application Support, marked to stay out of device backups and iCloud. The
/// list of server addresses is nobody's business but this device's. A list saved by an earlier version in the
/// app's defaults moves here the first time it is read.
nonisolated struct FileServerStore: ServerStoring {
    private static let logger = Logger(subsystem: "com.therabbithole.app.apple.sneakers-pam", category: "servers")

    let folder: URL
    var legacyDefaults: UserDefaults = .standard

    var fileURL: URL {
        folder.appending(path: "servers.json")
    }

    /// The store the running app uses.
    static func standard() -> FileServerStore {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return FileServerStore(folder: support.appending(path: "Sneakers-PAM", directoryHint: .isDirectory))
    }

    func load() -> ServerList {
        if let data = try? Data(contentsOf: fileURL) {
            return (try? JSONDecoder().decode(ServerList.self, from: data)) ?? ServerList()
        }
        return migrateLegacyList()
    }

    func save(_ list: ServerList) {
        guard let data = try? JSONEncoder().encode(list) else { return }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var excluded = fileURL
            try excluded.setResourceValues(values)
        } catch {
            let reason = error.localizedDescription
            Self.logger.error("could not save the server list: \(reason, privacy: .public)")
        }
    }

    private func migrateLegacyList() -> ServerList {
        guard legacyDefaults.data(forKey: UserDefaultsServerStore.key) != nil else { return ServerList() }
        let list = UserDefaultsServerStore(defaults: legacyDefaults).load()
        save(list)
        legacyDefaults.removeObject(forKey: UserDefaultsServerStore.key)
        Self.logger.info("moved the server list out of the app defaults")
        return list
    }
}
