// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Sneakers_PAM

/// A clipboard that remembers what was copied and for how long.
final class FakeClipboard: Clipboard, @unchecked Sendable {
    private(set) var copies: [(value: String, clearAfter: TimeInterval)] = []

    func copy(_ value: String, clearAfter: TimeInterval) {
        copies.append((value, clearAfter))
    }
}
