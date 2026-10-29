// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Sneakers_PAM
import Testing

@MainActor
struct AppLockModelTests {
    private let authenticator = FakeAuthenticator()
    private let settings = InMemoryLockSettings()
    private let start = Date(timeIntervalSince1970: 1000)

    private func makeModel() -> AppLockModel {
        AppLockModel(authenticator: authenticator, settings: settings, policy: LockPolicy(gracePeriod: 30))
    }

    @Test func startsLockedWhenTheLockIsOn() {
        #expect(makeModel().isLocked)
    }

    @Test func startsOpenWhenTheLockIsOff() {
        settings.isEnabled = false
        #expect(!makeModel().isLocked)
    }

    @Test func aSuccessfulCheckUnlocks() async {
        let model = makeModel()

        await model.unlock()

        #expect(!model.isLocked)
        #expect(model.message == nil)
        #expect(authenticator.asks == 1)
    }

    @Test func theReasonIsPassedToTheDeviceCheck() async {
        let model = makeModel()

        await model.unlock(reason: "Unlock Sneakers-PAM for one.example.org")

        #expect(authenticator.lastReason == "Unlock Sneakers-PAM for one.example.org")
    }

    @Test func aCancelledCheckStaysLockedWithoutScolding() async {
        authenticator.result = .cancelled
        let model = makeModel()

        await model.unlock()

        #expect(model.isLocked)
        #expect(model.message == nil)
    }

    @Test func aFailedCheckStaysLockedAndSaysSo() async {
        authenticator.result = .failed
        let model = makeModel()

        await model.unlock()

        #expect(model.isLocked)
        #expect(model.message == "Couldn't unlock. Try again.")
    }

    @Test func aDeviceWithNoPasscodeCannotLockSoItOpensAndSaysSo() async {
        authenticator.result = .notAvailable
        let model = makeModel()

        await model.unlock()

        #expect(!model.isLocked)
        #expect(model.deviceCannotLock)
    }

    @Test func unlockingWhileAlreadyOpenDoesNotAsk() async {
        let model = makeModel()
        await model.unlock()

        await model.unlock()

        #expect(authenticator.asks == 1)
    }

    @Test func aShortTripToTheBackgroundKeepsTheAppOpen() async {
        let model = makeModel()
        await model.unlock()

        model.movedToBackground(at: start)
        model.becameActive(at: start.addingTimeInterval(10))

        #expect(!model.isLocked)
    }

    @Test func aLongTripToTheBackgroundLocksTheApp() async {
        let model = makeModel()
        await model.unlock()

        model.movedToBackground(at: start)
        model.becameActive(at: start.addingTimeInterval(45))

        #expect(model.isLocked)
    }

    @Test func theLockStaysOffWhenTheSettingIsOff() {
        settings.isEnabled = false
        let model = makeModel()

        model.movedToBackground(at: start)
        model.becameActive(at: start.addingTimeInterval(600))

        #expect(!model.isLocked)
    }

    @Test func signingInOpensTheAppWithoutAskingAgain() {
        let model = makeModel()

        model.signedInJustNow()

        #expect(!model.isLocked)
        #expect(authenticator.asks == 0)
    }

    @Test func turningTheLockOffOpensTheAppAndIsRemembered() {
        let model = makeModel()

        model.setEnabled(false)

        #expect(!model.isLocked)
        #expect(!model.isEnabled)
        #expect(settings.isEnabled == false)
    }

    @Test func turningTheLockOnIsRememberedAndDoesNotLockAtOnce() {
        settings.isEnabled = false
        let model = makeModel()

        model.setEnabled(true)

        #expect(model.isEnabled)
        #expect(!model.isLocked)
        #expect(settings.isEnabled)
    }

    @Test func theLockCoversTheAppWhenItIsNotActive() {
        let model = makeModel()

        model.movedToBackground(at: start)
        #expect(model.isCovered)

        model.becameActive(at: start.addingTimeInterval(1))
        #expect(!model.isCovered)
    }
}
