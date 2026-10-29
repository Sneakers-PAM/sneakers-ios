// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// Asks a server who it is, before anyone signs in. The real one calls the network; tests fake it.
nonisolated protocol ServerProbing: Sendable {
    func probe(_ url: ServerURL) async throws -> ServerProbeResult
}

/// What a server said about itself. Some servers do not announce a version before sign-in; then
/// `versionText` is nil and `looksLikeSneakers` says whether it still answered like one.
nonisolated struct ServerProbeResult: Equatable, Sendable {
    var versionText: String?
    var looksLikeSneakers: Bool = false
}

nonisolated enum ServerProbeError: Error, Equatable, Sendable {
    case unreachable
}
