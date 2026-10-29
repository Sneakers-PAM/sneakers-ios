// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Sneakers_PAM
import Testing

struct ReminderPolicyTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)
    private let day: TimeInterval = 86400

    @Test func theReminderStaysAwayWhenSetupIsNotRecommended() {
        #expect(!ReminderPolicy.standard.shows(setupRecommended: false, dismissedAt: nil, now: now))
    }

    @Test func theReminderShowsWhenSetupIsRecommendedAndNeverDismissed() {
        #expect(ReminderPolicy.standard.shows(setupRecommended: true, dismissedAt: nil, now: now))
    }

    @Test func aDismissedReminderStaysHiddenForThreeDays() {
        let dismissed = now.addingTimeInterval(-2 * day)
        #expect(!ReminderPolicy.standard.shows(setupRecommended: true, dismissedAt: dismissed, now: now))
    }

    @Test func aDismissedReminderComesBackAfterThreeDays() {
        let dismissed = now.addingTimeInterval(-3 * day)
        #expect(ReminderPolicy.standard.shows(setupRecommended: true, dismissedAt: dismissed, now: now))
    }

    @Test func aDismissalFromTheFutureIsIgnored() {
        let dismissed = now.addingTimeInterval(5 * day)
        #expect(ReminderPolicy.standard.shows(setupRecommended: true, dismissedAt: dismissed, now: now))
    }
}
