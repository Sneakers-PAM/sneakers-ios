// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Sneakers_PAM

/// An authenticator that answers with a scripted result and counts how often it was asked.
final class FakeAuthenticator: Authenticating, @unchecked Sendable {
    var result = LockResult.success
    private(set) var asks = 0
    private(set) var lastReason: String?

    func authenticate(reason: String) async -> LockResult {
        asks += 1
        lastReason = reason
        return result
    }
}

/// Lock settings held in memory.
final class InMemoryLockSettings: LockSettingStoring, @unchecked Sendable {
    var isEnabled: Bool

    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }

    func load() -> Bool {
        isEnabled
    }

    func save(_ isEnabled: Bool) {
        self.isEnabled = isEnabled
    }
}
