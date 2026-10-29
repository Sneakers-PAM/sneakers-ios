// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Sneakers_PAM
import Testing

@MainActor
struct AccessRequestTests {
    private let vault = FakeVaultService()
    private let transport = FakeGraphQLTransport()

    private func makeAccess() -> VaultAccess {
        VaultAccess(service: vault, context: { .fixture }, onSessionEnded: {})
    }

    @Test func askingForAccessSendsTheSecretAndTheReason() async throws {
        transport.answer("RequestsCreate", #"{"createAccessRequest":{"id":"r1"}}"#)

        try await HTTPVaultService(transport: transport).requestAccess(
            secretID: "s1",
            reason: "On call tonight",
            .fixture
        )

        let variables = transport.operation(named: "RequestsCreate")?.variables
        #expect(variables?["secretId"] == .string("s1"))
        #expect(variables?["reason"] == .string("On call tonight"))
    }

    @Test func aRequestWithNoReasonLeavesItOut() async throws {
        transport.answer("RequestsCreate", #"{"createAccessRequest":{"id":"r1"}}"#)

        try await HTTPVaultService(transport: transport).requestAccess(secretID: "s1", reason: "  ", .fixture)

        #expect(transport.operation(named: "RequestsCreate")?.variables["reason"] == nil)
    }

    @Test func sendingARequestAsksTheServerOnceAndSaysItWorked() async {
        let model = AccessRequestModel(secretID: "s1")
        model.reason = "On call tonight"

        await model.send(makeAccess())

        #expect(vault.accessRequests.first?.secretID == "s1")
        #expect(vault.accessRequests.first?.reason == "On call tonight")
        #expect(model.didSend)
        #expect(model.message == nil)
    }

    @Test func aRefusedRequestSaysWhyAndCanBeSentAgain() async {
        vault.requestAccessResult = .failure(.noAccess)
        let model = AccessRequestModel(secretID: "s1")

        await model.send(makeAccess())

        #expect(!model.didSend)
        #expect(model.message == VaultError.noAccess.message)
        #expect(model.canSend)
    }

    @Test func aRequestCannotBeSentTwice() async {
        let model = AccessRequestModel(secretID: "s1")
        await model.send(makeAccess())

        await model.send(makeAccess())

        #expect(vault.accessRequests.count == 1)
        #expect(!model.canSend)
    }
}
