// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Sneakers_PAM
import Testing

@MainActor
struct RevealCoordinatorTests {
    private let vault = FakeVaultService()
    private let auth = FakeAuthService()
    private let clipboard = FakeClipboard()
    private let key = RevealKey(secretID: "s1", fieldKey: "password")

    private func makeCoordinator(hideAfter: Duration = .seconds(60)) -> RevealCoordinator {
        let access = VaultAccess(service: vault, context: { .fixture }, onSessionEnded: {})
        return RevealCoordinator(access: access, auth: auth, clipboard: clipboard, hideAfter: hideAfter)
    }

    // MARK: Showing

    @Test func aRevealedValueIsHeldUnderItsKey() async {
        vault.revealResults = [.success("a-value")]
        let coordinator = makeCoordinator()

        await coordinator.show(key)

        #expect(coordinator.revealed[key] == "a-value")
        #expect(vault.revealRequests.first?.secretID == "s1")
        #expect(vault.revealRequests.first?.fieldKey == "password")
        #expect(coordinator.notice == nil)
    }

    @Test func aRevealedValueHidesItselfAfterAWhile() async throws {
        vault.revealResults = [.success("a-value")]
        let coordinator = makeCoordinator(hideAfter: .milliseconds(30))

        await coordinator.show(key)
        try await Task.sleep(for: .milliseconds(300))

        #expect(coordinator.revealed[key] == nil)
    }

    @Test func hidingAValueRemovesIt() async {
        vault.revealResults = [.success("a-value")]
        let coordinator = makeCoordinator()
        await coordinator.show(key)

        coordinator.hide(key)

        #expect(coordinator.revealed[key] == nil)
    }

    @Test func hidingEverythingClearsEveryValueAndTheNotice() async {
        vault.revealResults = [.success("one"), .success("two")]
        let coordinator = makeCoordinator()
        await coordinator.show(key)
        await coordinator.show(RevealKey(secretID: "s2", fieldKey: "password"))

        coordinator.hideAll()

        #expect(coordinator.revealed.isEmpty)
        #expect(coordinator.notice == nil)
    }

    // MARK: Copying

    @Test func copyingRevealsThenPutsTheValueOnTheClipboardWithoutKeepingItOnScreen() async {
        vault.revealResults = [.success("a-value")]
        let coordinator = makeCoordinator()

        await coordinator.copy(key)

        #expect(clipboard.copies.count == 1)
        #expect(clipboard.copies.first?.value == "a-value")
        #expect(clipboard.copies.first?.clearAfter == 60)
        #expect(coordinator.notice == "Copied. It clears in 60 seconds.")
        #expect(coordinator.revealed[key] == nil)
    }

    @Test func aValueAlreadyKnownCanBeCopiedWithoutAskingTheServer() {
        let coordinator = makeCoordinator()

        coordinator.copyKnown("app_admin")

        #expect(clipboard.copies.first?.value == "app_admin")
        #expect(vault.revealRequests.isEmpty)
        #expect(coordinator.notice == "Copied. It clears in 60 seconds.")
    }

    // MARK: Refusals

    @Test func aRefusedRevealShowsTheMessageAndKeepsNothing() async {
        vault.revealResults = [.failure(.noAccess)]
        let coordinator = makeCoordinator()

        await coordinator.show(key)

        #expect(coordinator.notice == VaultError.noAccess.message)
        #expect(coordinator.revealed.isEmpty)
        #expect(coordinator.stepUp == nil)
    }

    @Test func aSecretThatNeedsApprovalSaysSoAndAsksForNoCode() async {
        vault.revealResults = [.failure(.approvalRequired)]
        let coordinator = makeCoordinator()

        await coordinator.copy(key)

        #expect(coordinator.notice == VaultError.approvalRequired.message)
        #expect(coordinator.stepUp == nil)
        #expect(clipboard.copies.isEmpty)
    }

    // MARK: Step-up

    @Test func aRevealThatNeedsAFreshFactorAsksForACode() async {
        vault.revealResults = [.failure(.stepUpRequired)]
        let coordinator = makeCoordinator()

        await coordinator.show(key)

        #expect(coordinator.stepUp?.action == .show(key))
        #expect(coordinator.revealed.isEmpty)
    }

    @Test func aCorrectCodeProvesTheFactorAndRetriesTheReveal() async {
        vault.revealResults = [.failure(.stepUpRequired), .success("a-value")]
        let coordinator = makeCoordinator()
        await coordinator.show(key)

        await coordinator.submitStepUp(code: "123456", kind: .totp)

        #expect(auth.stepUps.first?.kind == .totp)
        #expect(auth.stepUps.first?.code == "123456")
        #expect(coordinator.revealed[key] == "a-value")
        #expect(coordinator.stepUp == nil)
    }

    @Test func aCorrectCodeAfterACopyFinishesTheCopy() async {
        vault.revealResults = [.failure(.stepUpRequired), .success("a-value")]
        let coordinator = makeCoordinator()
        await coordinator.copy(key)

        await coordinator.submitStepUp(code: "123456", kind: .email)

        #expect(clipboard.copies.first?.value == "a-value")
        #expect(coordinator.revealed[key] == nil)
        #expect(coordinator.stepUp == nil)
    }

    @Test func aWrongCodeKeepsThePromptAndSaysSo() async {
        vault.revealResults = [.failure(.stepUpRequired)]
        auth.stepUpResult = .failure(.invalidCode)
        let coordinator = makeCoordinator()
        await coordinator.show(key)

        await coordinator.submitStepUp(code: "123456", kind: .totp)

        #expect(coordinator.stepUp?.message == AuthError.invalidCode.message)
        #expect(coordinator.revealed.isEmpty)
        #expect(vault.revealRequests.count == 1)
    }

    @Test func aCodeThatIsNotSixDigitsIsRefusedWithoutAskingTheServer() async {
        vault.revealResults = [.failure(.stepUpRequired)]
        let coordinator = makeCoordinator()
        await coordinator.show(key)

        await coordinator.submitStepUp(code: "12345", kind: .totp)

        #expect(coordinator.stepUp?.message == "Enter the 6-digit code.")
        #expect(auth.stepUps.isEmpty)
    }

    @Test func cancellingThePromptDropsThePendingAction() async {
        vault.revealResults = [.failure(.stepUpRequired)]
        let coordinator = makeCoordinator()
        await coordinator.show(key)

        coordinator.cancelStepUp()

        #expect(coordinator.stepUp == nil)
    }

    @Test func anEmailedCodeCanBeRequestedForTheStepUp() async {
        vault.revealResults = [.failure(.stepUpRequired)]
        let coordinator = makeCoordinator()
        await coordinator.show(key)

        await coordinator.sendStepUpEmail()

        #expect(auth.stepUpEmailSends == 1)
    }

    @Test func askingForAnotherEmailTooSoonSaysSo() async {
        vault.revealResults = [.failure(.stepUpRequired)]
        auth.stepUpEmailResult = .failure(.rateLimited)
        let coordinator = makeCoordinator()
        await coordinator.show(key)

        await coordinator.sendStepUpEmail()

        #expect(coordinator.stepUp?.message == AuthError.rateLimited.message)
    }
}
