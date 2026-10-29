// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// One Sneakers server the person has added. Sign-in, tokens and data are kept per entry, never shared.
nonisolated struct ServerEntry: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let url: ServerURL
    let addedAt: Date
    /// The release the server reported when it was added. Nil until the app has checked it, after sign-in.
    var version: ServerVersion?

    var name: String {
        url.host
    }
}

/// What is saved between launches: the servers, in the order they were added, and the active one.
nonisolated struct ServerList: Codable, Equatable, Sendable {
    var entries: [ServerEntry] = []
    var activeID: UUID?
}
