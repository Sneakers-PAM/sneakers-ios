// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Sneakers_PAM
import Testing

struct RequestBoardTests {
    private func request(
        _ id: String,
        kind: ApprovalKind = .secretAccess,
        secret: String = "s1",
        by requester: String = "other",
        status: ApprovalStatus = .pending,
        resolvedBy: String? = nil,
        at day: Int = 1
    ) -> ApprovalRequest {
        ApprovalRequest(
            id: id, kind: kind, secretID: secret, folderName: nil, destParentName: nil, requestedByUserID: requester,
            requestedAt: Date(timeIntervalSince1970: TimeInterval(day * 86400)), reason: "Because",
            status: status, resolvedAt: nil, resolvedByUserID: resolvedBy, resolvedByName: nil, comments: []
        )
    }

    private func overview(_ requests: [ApprovalRequest], approve: Set<String> = ["s1"]) -> RequestsOverview {
        RequestsOverview(
            requests: requests, secretNames: ["s1": "DB admin", "s2": "Vendor key"], secretsIMayApprove: approve,
            people: ["other": "Alice", "me": "Me"]
        )
    }

    @Test func aPendingRequestFromSomeoneElseOnASecretIMayApproveAwaitsMe() {
        let board = RequestBoard(overview([request("r1")]), for: "me")

        #expect(board.awaiting.map(\.id) == ["r1"])
        #expect(board.awaiting.first?.canDecide == true)
        #expect(board.awaiting.first?.resource == "DB admin")
        #expect(board.awaiting.first?.requestedBy == "Alice")
    }

    @Test func aRequestOnASecretIMayNotApproveIsNotMineToDecide() {
        let board = RequestBoard(overview([request("r1", secret: "s2")]), for: "me")

        #expect(board.awaiting.isEmpty)
        #expect(board.open.isEmpty)
    }

    @Test func myOwnPendingRequestIsOpenAndNeverAwaitsMe() {
        let board = RequestBoard(overview([request("r1", by: "me")]), for: "me")

        #expect(board.awaiting.isEmpty)
        #expect(board.open.map(\.id) == ["r1"])
        #expect(board.open.first?.mine == true)
    }

    @Test func aMoveNeedsASiteAdminSoItNeverAwaitsMeHere() {
        let move = request("r1", kind: .secretMove)
        let board = RequestBoard(overview([move]), for: "me")

        #expect(board.awaiting.isEmpty)
        #expect(RequestBoard(overview([move]), for: "me", isAdmin: true).awaiting.map(\.id) == ["r1"])
    }

    @Test func decidedRequestsOfMineOrDecidedByMeAreHistoryNewestFirst() {
        var list = [request("old", by: "me", status: .approved, at: 1)]
        list.append(request("new", by: "me", status: .denied, at: 5))
        list.append(request("mine-to-decide", by: "other", status: .approved, resolvedBy: "me", at: 3))
        list.append(request("unrelated", secret: "s2", by: "other", status: .approved, resolvedBy: "someone", at: 9))

        let board = RequestBoard(overview(list), for: "me")

        #expect(board.history.map(\.id) == ["new", "mine-to-decide", "old"])
    }

    @Test func aRowTitleSaysWhatWasAskedFor() {
        let access = RequestBoard(overview([request("r1")]), for: "me").awaiting[0]
        #expect(access.title == "Access to DB admin")

        var move = request("r2", kind: .folderMove, by: "me")
        move = ApprovalRequest(
            id: move.id, kind: .folderMove, secretID: "", folderName: "Platform", destParentName: "Theirs",
            requestedByUserID: "me", requestedAt: nil, reason: nil, status: .pending, resolvedAt: nil,
            resolvedByUserID: nil, resolvedByName: nil, comments: []
        )
        #expect(RequestBoard(overview([move]), for: "me").open[0].title == "Move Platform to Theirs")
    }

    @Test func theKindsAndStatesComeFromTheGatewaysWords() {
        #expect(ApprovalKind(gateway: "secret_access") == .secretAccess)
        #expect(ApprovalKind(gateway: "folder_move") == .folderMove)
        #expect(ApprovalKind(gateway: "secret_move") == .secretMove)
        #expect(ApprovalKind(gateway: "new thing") == .secretAccess)
        #expect(ApprovalStatus(gateway: "approved") == .approved)
        #expect(ApprovalStatus(gateway: "denied") == .denied)
        #expect(ApprovalStatus(gateway: "pending") == .pending)
        #expect(ApprovalStatus.denied.label == "Denied")
    }

    @Test func aGrantIsEightHoursUnlessChosenAndNeverMoreThanTwentyFour() {
        #expect(GrantHours.standard == 8)
        #expect(GrantHours.choices == [1, 4, 8, 24])
        #expect(GrantHours.choices.max() == GrantHours.longest)
    }
}
