// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Sneakers_PAM
import Testing

struct HTTPVaultRequestsTests {
    private let transport = FakeGraphQLTransport()
    private var service: HTTPVaultService {
        HTTPVaultService(transport: transport)
    }

    private let requestJSON = """
    {"id":"r1","kind":"secret_access","secretId":"s1","folderId":null,"folderName":null,"destParentId":null,
     "destParentName":null,"requestedByUserId":"u2","requestedAt":"2026-10-28T12:00:00Z","reason":"On call",
     "status":"pending","resolvedAt":null,"resolvedByUserId":null,"resolvedByUserName":null,
     "comments":[{"id":"c1","authorUserId":"u2","authorName":"Alice","body":"Please",
       "createdAt":"2026-10-28T12:05:00Z"}]}
    """

    @Test func theOverviewJoinsTheRequestsTheirSecretsMyRightsAndThePeople() async throws {
        transport.answer("RequestsList", #"{"approvalRequests":[\#(requestJSON)]}"#)
        transport.answer("RequestsSecrets", #"{"n0":{"id":"s1","name":"DB admin"},"a0":{"approve":true}}"#)
        transport.answer("RequestsPeople", #"{"resolveUserLabels":[{"id":"u2","name":"Alice"}]}"#)

        let overview = try await service.requestsOverview(.fixture)

        #expect(overview.requests.map(\.id) == ["r1"])
        #expect(overview.requests.first?.status == .pending)
        #expect(overview.requests.first?.comments.first?.body == "Please")
        #expect(overview.secretNames["s1"] == "DB admin")
        #expect(overview.secretsIMayApprove == ["s1"])
        #expect(overview.people["u2"] == "Alice")
    }

    @Test func aSecretIMayNotApproveIsNotListedAsApprovable() async throws {
        transport.answer("RequestsList", #"{"approvalRequests":[\#(requestJSON)]}"#)
        transport.answer("RequestsSecrets", #"{"n0":{"id":"s1","name":"DB admin"},"a0":{"approve":false}}"#)
        transport.answer("RequestsPeople", #"{"resolveUserLabels":[]}"#)

        let overview = try await service.requestsOverview(.fixture)

        #expect(overview.secretsIMayApprove.isEmpty)
    }

    @Test func noRequestsMeansNoFurtherQueries() async throws {
        transport.answer("RequestsList", #"{"approvalRequests":[]}"#)

        let overview = try await service.requestsOverview(.fixture)

        #expect(overview.requests.isEmpty)
        #expect(transport.operation(named: "RequestsSecrets") == nil)
        #expect(transport.operation(named: "RequestsPeople") == nil)
    }

    @Test func approvingSendsTheHoursAndDenyingSendsNone() async throws {
        transport.answer("RequestsResolve", #"{"resolveApproval":{"id":"r1"}}"#)

        try await service.resolve(requestID: "r1", approve: true, grantHours: 4, .fixture)
        var variables = transport.operation(named: "RequestsResolve")?.variables
        #expect(variables?["id"] == .string("r1"))
        #expect(variables?["approve"] == .bool(true))
        #expect(variables?["grantHours"] == .int(4))

        try await service.resolve(requestID: "r1", approve: false, grantHours: nil, .fixture)
        variables = transport.operation(named: "RequestsResolve")?.variables
        #expect(variables?["approve"] == .bool(false))
        #expect(variables?["grantHours"] == nil)
    }

    @Test func aCommentSendsTheRequestAndTheText() async throws {
        transport.answer("RequestsComment", #"{"addApprovalComment":{"id":"r1"}}"#)

        try await service.comment(requestID: "r1", body: "Looks fine", .fixture)

        let variables = transport.operation(named: "RequestsComment")?.variables
        #expect(variables?["requestId"] == .string("r1"))
        #expect(variables?["body"] == .string("Looks fine"))
    }

    @Test func theUsesWaitingOnMeAreListed() async throws {
        transport.answer("ApprovalsUsesToDecide", """
        {"secretUsesToDecide":[{"id":"u1","secretName":"DB admin","fieldKey":"password","state":"PENDING",
          "expiresAtUnix":1793300000,"purpose":"Rotate the cert","requester":"ci-bot","requestedBy":"Alice",
          "confirm":false,"runId":"run1","reveal":true}]}
        """)

        let uses = try await service.usesToDecide(.fixture)

        #expect(uses.first?.secretName == "DB admin")
        #expect(uses.first?.requestedBy == "Alice")
        #expect(uses.first?.purpose == "Rotate the cert")
        #expect(uses.first?.expiresAt == Date(timeIntervalSince1970: 1_793_300_000))
    }

    @Test func myOwnPendingUsesAreListed() async throws {
        transport.answer("RequestsMyUses", #"{"pendingSecretUses":[]}"#)

        #expect(try await service.myPendingUses(.fixture).isEmpty)
    }

    @Test func decidingAUseSendsItsIdAndTheAnswer() async throws {
        transport.answer("ApprovalsDecideUse", #"{"decideSecretUse":{"id":"u1","state":"APPROVED"}}"#)

        try await service.decideUse(id: "u1", approve: true, .fixture)

        let variables = transport.operation(named: "ApprovalsDecideUse")?.variables
        #expect(variables?["id"] == .string("u1"))
        #expect(variables?["approve"] == .bool(true))
    }

    @Test func aRefusedDecisionSaysWhy() async {
        transport.fail("RequestsResolve", .noAccess)

        await #expect(throws: VaultError.noAccess) {
            try await service.resolve(requestID: "r1", approve: true, grantHours: 8, .fixture)
        }
    }
}
