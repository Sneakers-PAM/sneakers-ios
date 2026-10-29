// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// A reveal the vault is holding until someone approves it. The value is read with `redeem`, once, after approval.
nonisolated struct HeldReveal: Equatable, Sendable {
    let id: String
    let state: String
    /// Nobody else can decide it, so the person who asked confirms it with a second factor.
    let confirm: Bool
    let expiresAt: Date
    let runID: String?

    var isApproved: Bool {
        state == "APPROVED"
    }
}
