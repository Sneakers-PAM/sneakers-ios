// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Sneakers_PAM
import Testing

@MainActor
struct RevealApprovalTests {
    private let vault = FakeVaultService()
    private let auth = FakeAuthService()
    private let clipboard = FakeClipboard()
    private let key = RevealKey(secretID: "s1", fieldKey: "password")

    private func makeCoordinator(poll: Duration = .milliseconds(20)) -> RevealCoordinator {
        let access = VaultAccess(service: vault, context: { .fixture }, onSessionEnded: {})
        return RevealCoordinator(access: access, auth: auth, clipboard: clipboard, pollEvery: poll)
    }

    private func held(_ state: String, id: String = "u1", in seconds: TimeInterval = 600) -> HeldReveal {
        HeldReveal(
            id: id, state: state, confirm: false, expiresAt: Date().addingTimeInterval(seconds), runID: "ios_run"
        )
    }

    @Test func aRevealThatNeedsApprovalStartsAHeldRequestInsteadOfShowingAnything() async {
        vault.revealResults = [.failure(.approvalRequired)]
        vault.prepareResults = [.success(held("PENDING"))]
        let coordinator = makeCoordinator()

        await coordinator.show(key)

        #expect(coordinator.held[key]?.id == "u1")
        #expect(coordinator.revealed[key] == nil)
        #expect(vault.prepared.first?.secretID == "s1")
        #expect(vault.prepared.first?.fieldKey == "password")
    }

    @Test func aRevealAlreadyApprovedIsReadAtOnce() async {
        vault.revealResults = [.failure(.approvalRequired)]
        vault.prepareResults = [.success(held("APPROVED"))]
        vault.redeemResults = [.success("the-value")]
        let coordinator = makeCoordinator()

        await coordinator.show(key)

        #expect(coordinator.revealed[key] == "the-value")
        #expect(coordinator.held[key] == nil)
        #expect(vault.redeemed == ["u1"])
    }

    @Test func aHeldRevealIsReadOnceItIsApproved() async throws {
        vault.revealResults = [.failure(.approvalRequired)]
        vault.prepareResults = [.success(held("PENDING"))]
        vault.redeemResults = [.failure(.approvalPending), .failure(.approvalPending), .success("the-value")]
        let coordinator = makeCoordinator()

        await coordinator.show(key)
        try await Task.sleep(for: .milliseconds(400))

        #expect(coordinator.revealed[key] == "the-value")
        #expect(coordinator.held[key] == nil)
        #expect(vault.redeemed.count == 3)
    }

    @Test func aHeldCopyCopiesTheValueOnceItIsApproved() async throws {
        vault.revealResults = [.failure(.approvalRequired)]
        vault.prepareResults = [.success(held("PENDING"))]
        vault.redeemResults = [.success("the-value")]
        let coordinator = makeCoordinator()

        await coordinator.copy(key)
        try await Task.sleep(for: .milliseconds(300))

        #expect(clipboard.copies.first?.value == "the-value")
        #expect(coordinator.revealed[key] == nil)
    }

    @Test func aDeniedHeldRevealSaysSoAndStopsWaiting() async throws {
        vault.revealResults = [.failure(.approvalRequired)]
        vault.prepareResults = [.success(held("PENDING"))]
        vault.redeemResults = [.failure(.noAccess)]
        let coordinator = makeCoordinator()

        await coordinator.show(key)
        try await Task.sleep(for: .milliseconds(300))

        #expect(coordinator.held[key] == nil)
        #expect(coordinator.notice == VaultError.noAccess.message)
        #expect(coordinator.revealed[key] == nil)
    }

    @Test func aHeldRevealThatExpiresSaysSoAndStopsWaiting() async throws {
        vault.revealResults = [.failure(.approvalRequired)]
        vault.prepareResults = [.success(held("PENDING", in: 0.05))]
        vault.redeemResults = [.failure(.approvalPending), .failure(.approvalPending), .failure(.approvalPending)]
        let coordinator = makeCoordinator()

        await coordinator.show(key)
        try await Task.sleep(for: .milliseconds(400))

        #expect(coordinator.held[key] == nil)
        #expect(coordinator.notice == "The approval request expired. Ask again.")
    }

    @Test func cancellingAHeldRevealStopsAskingForIt() async throws {
        vault.revealResults = [.failure(.approvalRequired)]
        vault.prepareResults = [.success(held("PENDING"))]
        vault.redeemResults = Array(repeating: .failure(.approvalPending), count: 50)
        let coordinator = makeCoordinator()
        await coordinator.show(key)

        coordinator.cancelHeld(key)
        let before = vault.redeemed.count
        try await Task.sleep(for: .milliseconds(200))

        #expect(coordinator.held[key] == nil)
        #expect(vault.redeemed.count <= before + 1)
    }

    @Test func revealsOfOneSecretShareARunAndAnotherSecretGetsItsOwn() async {
        vault.revealResults = [.failure(.approvalRequired), .failure(.approvalRequired), .failure(.approvalRequired)]
        vault.prepareResults = [.success(held("PENDING"))]
        vault.prepareResults.append(.success(held("PENDING", id: "u2")))
        vault.prepareResults.append(.success(held("PENDING", id: "u3")))
        let coordinator = makeCoordinator(poll: .seconds(60))

        await coordinator.show(key)
        await coordinator.show(RevealKey(secretID: "s1", fieldKey: "username"))
        await coordinator.show(RevealKey(secretID: "s2", fieldKey: "password"))

        let runs = vault.prepared.map(\.runID)
        #expect(runs[0] == runs[1])
        #expect(runs[0] != runs[2])
        #expect(runs[0].hasPrefix("ios_"))
    }

    @Test func hidingEverythingStopsEveryHeldReveal() async {
        vault.revealResults = [.failure(.approvalRequired)]
        vault.prepareResults = [.success(held("PENDING"))]
        let coordinator = makeCoordinator(poll: .seconds(60))
        await coordinator.show(key)

        coordinator.hideAll()

        #expect(coordinator.held.isEmpty)
    }
}
