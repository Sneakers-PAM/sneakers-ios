// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Sneakers_PAM
import Testing

@MainActor
struct RequestsModelTests {
    private let vault = FakeVaultService()
    private let authenticator = FakeAuthenticator()

    private func makeAccess() -> VaultAccess {
        VaultAccess(service: vault, context: { .fixture }, onSessionEnded: {})
    }

    private func request(_ id: String, by requester: String = "other") -> ApprovalRequest {
        ApprovalRequest(
            id: id, kind: .secretAccess, secretID: "s1", folderName: nil, destParentName: nil,
            requestedByUserID: requester, requestedAt: Date(), reason: "Because", status: .pending, resolvedAt: nil,
            resolvedByUserID: nil, resolvedByName: nil, comments: []
        )
    }

    private func use(_ id: String = "use1") -> SecretUse {
        SecretUse(
            id: id, secretName: "DB admin", fieldKey: "password", state: "PENDING",
            expiresAt: Date().addingTimeInterval(600),
            purpose: "Rotate", requester: "bot", requestedBy: "Alice", confirm: false, runID: nil
        )
    }

    private func loaded() async -> RequestsModel {
        var list = [request("r1")]
        list.append(request("r2", by: "me"))
        vault.overviewResult = .success(RequestsOverview(
            requests: list, secretNames: ["s1": "DB admin"], secretsIMayApprove: ["s1"], people: ["other": "Alice"]
        ))
        vault.usesToDecideResult = .success([use()])
        let model = RequestsModel(authenticator: authenticator)
        await model.load(makeAccess())
        return model
    }

    @Test func startsLoading() {
        #expect(RequestsModel(authenticator: authenticator).phase == .loading)
    }

    @Test func loadingBuildsTheBoardForMeAndListsTheUsesWaitingOnMe() async {
        let model = await loaded()

        #expect(model.phase == .loaded)
        #expect(model.board.awaiting.map(\.id) == ["r1"])
        #expect(model.board.open.map(\.id) == ["r2"])
        #expect(model.usesToDecide.map(\.id) == ["use1"])
        #expect(model.awaitingCount == 2)
    }

    @Test func requestsThatCannotLoadSaySoAndCanBeRetried() async {
        vault.overviewResult = .failure(.unreachable)
        let model = RequestsModel(authenticator: authenticator)

        await model.load(makeAccess())

        #expect(model.phase == .failed(VaultError.unreachable.message))
    }

    @Test func approvingAsksTheDeviceFirstThenSendsTheHours() async {
        let model = await loaded()

        await model.decide("r1", approve: true, hours: 4, makeAccess())

        #expect(authenticator.asks == 1)
        #expect(vault.resolutions == [Resolution(requestID: "r1", approve: true, grantHours: 4)])
    }

    @Test func denyingSendsNoHours() async {
        let model = await loaded()

        await model.decide("r1", approve: false, hours: 4, makeAccess())

        #expect(vault.resolutions == [Resolution(requestID: "r1", approve: false, grantHours: nil)])
    }

    @Test func aCancelledDeviceCheckDecidesNothing() async {
        authenticator.result = .cancelled
        let model = await loaded()

        await model.decide("r1", approve: true, hours: 8, makeAccess())

        #expect(vault.resolutions.isEmpty)
        #expect(model.message == nil)
    }

    @Test func aFailedDeviceCheckDecidesNothingAndSaysSo() async {
        authenticator.result = .failed
        let model = await loaded()

        await model.decide("r1", approve: true, hours: 8, makeAccess())

        #expect(vault.resolutions.isEmpty)
        #expect(model.message == RequestsModel.notConfirmed)
    }

    @Test func aDeviceWithNoPasscodeCannotApprove() async {
        authenticator.result = .notAvailable
        let model = await loaded()

        await model.decide("r1", approve: true, hours: 8, makeAccess())

        #expect(vault.resolutions.isEmpty)
        #expect(model.message == RequestsModel.noPasscode)
    }

    @Test func aRefusedDecisionSaysWhy() async {
        let model = await loaded()
        vault.decisionResult = .failure(.noAccess)

        await model.decide("r1", approve: true, hours: 8, makeAccess())

        #expect(model.message == VaultError.noAccess.message)
    }

    @Test func decidingAUseAsksTheDeviceThenTheServer() async {
        let model = await loaded()

        await model.decideUse(use(), approve: true, makeAccess())

        #expect(authenticator.asks == 1)
        #expect(vault.useDecisions.first?.id == "use1")
        #expect(vault.useDecisions.first?.approve == true)
    }

    @Test func aCommentIsTrimmedAndAnEmptyOneIsNotSent() async {
        let model = await loaded()

        await model.comment("r1", body: "   ", makeAccess())
        await model.comment("r1", body: "  Looks fine ", makeAccess())

        #expect(vault.comments.count == 1)
        #expect(vault.comments.first?.body == "Looks fine")
    }

    @Test func resettingForgetsEverythingTheLastPersonSaw() async {
        let model = await loaded()

        model.reset()

        #expect(model.phase == .loading)
        #expect(model.awaitingCount == 0)
        #expect(model.board.awaiting.isEmpty)
    }
}
