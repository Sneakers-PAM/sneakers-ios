// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

extension ServerRegistry {
    /// Launch arguments the UI tests pass so they start from a known list and save nothing.
    static let emptyServersArgument = "-uiTestingEmptyServers"
    static let oneServerArgument = "-uiTestingOneServer"

    /// The registry the running app uses: the saved list and the real network probe.
    static func live(arguments: [String] = CommandLine.arguments) -> ServerRegistry {
        ServerRegistry(store: store(for: arguments), probe: HTTPServerProbe(), policy: .current)
    }

    private static func store(for arguments: [String]) -> ServerStoring {
        if arguments.contains(oneServerArgument), let url = try? ServerURL(input: "one.example.org") {
            let entry = ServerEntry(id: UUID(), url: url, addedAt: Date(timeIntervalSince1970: 0), version: nil)
            return TransientServerStore(list: ServerList(entries: [entry], activeID: entry.id))
        }
        if arguments.contains(emptyServersArgument) {
            return TransientServerStore(list: ServerList())
        }
        return UserDefaultsServerStore()
    }
}

/// Starts from a fixed list and keeps nothing between launches. Only the UI tests use it.
private final class TransientServerStore: ServerStoring {
    private let list: ServerList

    init(list: ServerList) {
        self.list = list
    }

    func load() -> ServerList {
        list
    }

    func save(_: ServerList) {}
}
