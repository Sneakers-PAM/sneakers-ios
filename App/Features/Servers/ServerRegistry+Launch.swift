// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

extension ServerRegistry {
    /// The launch argument UI tests pass so they always start with no servers and save nothing.
    static let emptyServersArgument = "-uiTestingEmptyServers"

    /// The registry the running app uses: the saved list and the real network probe.
    static func live(arguments: [String] = CommandLine.arguments) -> ServerRegistry {
        let store: ServerStoring = arguments
            .contains(emptyServersArgument) ? TransientServerStore() : UserDefaultsServerStore()
        return ServerRegistry(store: store, probe: HTTPServerProbe(), policy: .current)
    }
}

/// Keeps nothing between launches. Only the UI tests use it.
private final class TransientServerStore: ServerStoring {
    func load() -> ServerList {
        ServerList()
    }

    func save(_: ServerList) {}
}
