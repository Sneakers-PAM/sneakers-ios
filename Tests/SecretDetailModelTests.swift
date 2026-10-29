// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Sneakers_PAM
import Testing

@MainActor
struct SecretDetailModelTests {
    private let vault = FakeVaultService()

    private func makeAccess() -> VaultAccess {
        VaultAccess(service: vault, context: { .fixture }, onSessionEnded: {})
    }

    private func lease(user: String?, expires: String = "2026-10-28T14:00:00Z") -> Lease {
        Lease(
            id: "l1",
            secretId: "s1",
            userId: user,
            issuedAt: "2026-10-28T12:00:00Z",
            expiresAt: expires,
            returned: false
        )
    }

    private func detail(lease: Lease? = nil, canRead: Bool? = true) -> SecretDetail {
        SecretDetail(
            summary: .fixture(id: "s1", name: "DB admin", canRead: canRead),
            type: .databaseFixture,
            values: ["username": "app_admin"],
            lease: lease,
            folderPath: "Platform / Databases",
            expiresAt: nil,
            verifiedAt: nil,
            nextRotationAt: nil
        )
    }

    // MARK: Loading

    @Test func startsLoading() {
        #expect(SecretDetailModel(secretID: "s1").phase == .loading)
    }

    @Test func aLoadedSecretHoldsItsDetail() async {
        vault.detailResult = .success(detail())
        let model = SecretDetailModel(secretID: "s1")

        await model.load(makeAccess())

        #expect(model.phase == .loaded(detail()))
    }

    @Test func aSecretThatIsNotThereSaysSo() async {
        vault.detailResult = .failure(.notFound)
        let model = SecretDetailModel(secretID: "s1")

        await model.load(makeAccess())

        #expect(model.phase == .failed(VaultError.notFound.message))
    }

    // MARK: Fields

    @Test func eachFieldIsEitherAValueToShowOrASensitiveOneToReveal() async {
        vault.detailResult = .success(detail())
        let model = SecretDetailModel(secretID: "s1")
        await model.load(makeAccess())

        let rows = model.fieldRows
        #expect(rows.map(\.key) == ["username", "password"])
        #expect(rows[0].plainValue == "app_admin")
        #expect(rows[0].isSensitive == false)
        #expect(rows[1].plainValue == nil)
        #expect(rows[1].isSensitive == true)
    }

    @Test func aSecretTheUserCannotReadShowsNoFieldRows() async {
        vault.detailResult = .success(detail(canRead: false))
        let model = SecretDetailModel(secretID: "s1")
        await model.load(makeAccess())

        #expect(model.fieldRows.isEmpty)
    }

    // MARK: Lease state

    @Test func aFreeSecretCanBeCheckedOutWhenItsTypeAllowsIt() async {
        vault.detailResult = .success(detail(lease: nil))
        let model = SecretDetailModel(secretID: "s1")
        await model.load(makeAccess())

        #expect(model.leaseState(userID: "me") == .free)
        #expect(model.canCheckOut)
    }

    @Test func aSecretIHaveCheckedOutShowsTheCountdownTarget() async {
        vault.detailResult = .success(detail(lease: lease(user: "me")))
        let model = SecretDetailModel(secretID: "s1")
        await model.load(makeAccess())

        let state = model.leaseState(userID: "me")
        #expect(state == .heldByMe(expires: GatewayDate.parse("2026-10-28T14:00:00Z")))
        #expect(!model.canCheckOut)
        #expect(model.canCheckIn(userID: "me"))
    }

    @Test func aSecretSomeoneElseHoldsCannotBeCheckedOutOrIn() async {
        vault.detailResult = .success(detail(lease: lease(user: "u2")))
        let model = SecretDetailModel(secretID: "s1")
        await model.load(makeAccess())

        #expect(model.leaseState(userID: "me") == .heldByOther(expires: GatewayDate.parse("2026-10-28T14:00:00Z")))
        #expect(!model.canCheckOut)
        #expect(!model.canCheckIn(userID: "me"))
    }

    // MARK: Check out and in

    @Test func checkingOutTakesTheNewLease() async {
        vault.detailResult = .success(detail(lease: nil))
        vault.checkoutResult = .success(lease(user: "me"))
        let model = SecretDetailModel(secretID: "s1")
        await model.load(makeAccess())

        await model.checkOut(makeAccess())

        #expect(vault.checkouts == 1)
        #expect(model.leaseState(userID: "me") != .free)
        #expect(model.message == nil)
    }

    @Test func aCheckoutSomeoneElseHoldsShowsAMessage() async {
        vault.detailResult = .success(detail(lease: nil))
        vault.checkoutResult = .failure(.leaseHeld)
        let model = SecretDetailModel(secretID: "s1")
        await model.load(makeAccess())

        await model.checkOut(makeAccess())

        #expect(model.message == VaultError.leaseHeld.message)
        #expect(model.leaseState(userID: "me") == .free)
    }

    @Test func checkingInReleasesTheLease() async {
        vault.detailResult = .success(detail(lease: lease(user: "me")))
        let model = SecretDetailModel(secretID: "s1")
        await model.load(makeAccess())

        await model.checkIn(makeAccess())

        #expect(vault.checkins == 1)
        #expect(model.leaseState(userID: "me") == .free)
    }

    @Test func aCheckinByAnotherPersonShowsAMessageAndKeepsTheLease() async {
        vault.detailResult = .success(detail(lease: lease(user: "u2")))
        vault.checkinResult = .failure(.notHolder)
        let model = SecretDetailModel(secretID: "s1")
        await model.load(makeAccess())

        await model.checkIn(makeAccess())

        #expect(model.message == VaultError.notHolder.message)
        #expect(model.leaseState(userID: "me") != .free)
    }

    // MARK: Access

    @Test func aSecretIAmAllowedToManageCanBeEdited() async {
        vault.detailResult = .success(detail())
        vault.secretAccessResult = .success(.fixtureFull)
        let model = SecretDetailModel(secretID: "s1")

        await model.load(makeAccess())

        #expect(model.access.manage)
        #expect(model.canEdit)
    }

    @Test func aSecretIOnlyReadCannotBeEdited() async {
        vault.detailResult = .success(detail())
        vault.secretAccessResult = .success(.fixtureReadOnly)
        let model = SecretDetailModel(secretID: "s1")

        await model.load(makeAccess())

        #expect(!model.canEdit)
    }

    @Test func whenAccessCannotBeReadNothingCanBeChanged() async {
        vault.detailResult = .success(detail())
        vault.secretAccessResult = .failure(.unreachable)
        let model = SecretDetailModel(secretID: "s1")

        await model.load(makeAccess())

        #expect(model.access == .none)
        #expect(!model.canEdit)
        #expect(model.phase == .loaded(detail()))
    }

    @Test func theEditDraftStartsFromTheSecretsNameAndPlainValues() async throws {
        vault.detailResult = .success(detail())
        vault.secretAccessResult = .success(.fixtureFull)
        let model = SecretDetailModel(secretID: "s1")
        await model.load(makeAccess())

        let edit = try #require(model.makeEditModel())

        #expect(edit.name == "DB admin")
        #expect(edit.value(for: "username") == "app_admin")
        #expect(edit.value(for: "password") == "")
    }

    @Test func thereIsNoEditDraftForASecretIMayNotManage() async {
        vault.detailResult = .success(detail())
        vault.secretAccessResult = .success(.fixtureReadOnly)
        let model = SecretDetailModel(secretID: "s1")
        await model.load(makeAccess())

        #expect(model.makeEditModel() == nil)
    }

    @Test func eachFieldRowKnowsItsKind() async {
        vault.detailResult = .success(detail())
        let model = SecretDetailModel(secretID: "s1")
        await model.load(makeAccess())

        #expect(model.fieldRows.map(\.kind) == [.text, .text])
    }
}
