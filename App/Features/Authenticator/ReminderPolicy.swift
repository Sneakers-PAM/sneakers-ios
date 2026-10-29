// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// When to nag about setting up a second factor. A dismissed reminder stays away for a while, then comes back.
nonisolated struct ReminderPolicy: Sendable {
    static let standard = ReminderPolicy(quietPeriod: 3 * 24 * 60 * 60)

    let quietPeriod: TimeInterval

    func shows(setupRecommended: Bool, dismissedAt: Date?, now: Date) -> Bool {
        guard setupRecommended else { return false }
        guard let dismissedAt else { return true }
        let since = now.timeIntervalSince(dismissedAt)
        return since < 0 || since >= quietPeriod
    }
}
