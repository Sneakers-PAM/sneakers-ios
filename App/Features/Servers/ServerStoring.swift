// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// Keeps the server list between launches. It holds addresses only, never tokens or secrets.
nonisolated protocol ServerStoring {
    func load() -> ServerList
    func save(_ list: ServerList)
}
