// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// Saves the server list as JSON in the app's own defaults. It holds addresses only, so it is not secret.
nonisolated struct UserDefaultsServerStore: ServerStoring {
    static let key = "servers.list"

    var defaults: UserDefaults = .standard

    func load() -> ServerList {
        guard let data = defaults.data(forKey: Self.key),
              let list = try? JSONDecoder().decode(ServerList.self, from: data)
        else {
            return ServerList()
        }
        return list
    }

    func save(_ list: ServerList) {
        guard let data = try? JSONEncoder().encode(list) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
