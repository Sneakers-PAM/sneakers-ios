// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Sneakers_PAM
import Testing

struct LockPolicyTests {
    private let policy = LockPolicy(gracePeriod: 30)
    private let start = Date(timeIntervalSince1970: 1000)

    @Test func theGracePeriodIsThirtySecondsByDefault() {
        #expect(LockPolicy.standard.gracePeriod == 30)
    }

    @Test func aShortTripToTheBackgroundDoesNotLock() {
        #expect(!policy.shouldLock(backgroundedAt: start, now: start.addingTimeInterval(10)))
    }

    @Test func aLongStayInTheBackgroundLocks() {
        #expect(policy.shouldLock(backgroundedAt: start, now: start.addingTimeInterval(30)))
        #expect(policy.shouldLock(backgroundedAt: start, now: start.addingTimeInterval(600)))
    }

    @Test func comingBackWithoutEverLeavingDoesNotLock() {
        #expect(!policy.shouldLock(backgroundedAt: nil, now: start))
    }

    @Test func aClockThatWentBackwardsLocksToBeSafe() {
        #expect(policy.shouldLock(backgroundedAt: start, now: start.addingTimeInterval(-5)))
    }
}
