// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Sneakers_PAM

/// A probe that answers from a table keyed by host and counts how often it was asked.
final class FakeServerProbe: ServerProbing, @unchecked Sendable {
    private(set) var probedHosts: [String] = []
    var answers: [String: Result<ServerProbeResult, ServerProbeError>] = [:]

    func answer(_ host: String, version: String?, looksLikeSneakers: Bool = true) {
        answers[host] = .success(ServerProbeResult(versionText: version, looksLikeSneakers: looksLikeSneakers))
    }

    func probe(_ url: ServerURL) async throws -> ServerProbeResult {
        probedHosts.append(url.host)
        guard let answer = answers[url.host] else { throw ServerProbeError.unreachable }
        return try answer.get()
    }
}

/// A store that keeps the list in memory and remembers the last thing saved.
final class InMemoryServerStore: ServerStoring {
    var contents: ServerList
    private(set) var saveCount = 0

    init(contents: ServerList = ServerList()) {
        self.contents = contents
    }

    func load() -> ServerList {
        contents
    }

    func save(_ list: ServerList) {
        contents = list
        saveCount += 1
    }
}
