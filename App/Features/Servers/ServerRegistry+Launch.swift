// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

extension ServerRegistry {
    /// The registry the running app uses: the saved list and the real network probe.
    static func live(arguments: [String] = CommandLine.arguments) -> ServerRegistry {
        ServerRegistry(store: store(for: arguments), probe: HTTPServerProbe(), policy: .current)
    }

    private static func store(for arguments: [String]) -> ServerStoring {
        #if DEBUG
            if let store = uiTestingStore(for: arguments) {
                return store
            }
        #endif
        return FileServerStore.standard()
    }
}

#if DEBUG
    extension ServerRegistry {
        /// Launch arguments the UI tests pass so they start from a known list and save nothing. Debug builds only.
        static let emptyServersArgument = "-uiTestingEmptyServers"
        static let oneServerArgument = "-uiTestingOneServer"

        /// The id of the one server the UI tests start with, so a signed-in session can be seeded for it.
        static let uiTestingServerID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))

        fileprivate static func uiTestingStore(for arguments: [String]) -> ServerStoring? {
            let seeded = [oneServerArgument, SessionManager.signedInArgument, SessionManager.enrolmentRequiredArgument]
            let wantsOne = seeded.contains(where: arguments.contains)
            if wantsOne, let url = try? ServerURL(input: "one.example.org") {
                let entry = ServerEntry(
                    id: uiTestingServerID,
                    url: url,
                    addedAt: Date(timeIntervalSince1970: 0),
                    version: nil
                )
                return TransientServerStore(list: ServerList(entries: [entry], activeID: entry.id))
            }
            if arguments.contains(emptyServersArgument) {
                return TransientServerStore(list: ServerList())
            }
            return nil
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
#endif
