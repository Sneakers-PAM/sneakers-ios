// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Sneakers_PAM
import Testing

struct HTTPVaultLifecycleTests {
    private let transport = FakeGraphQLTransport()
    private var service: HTTPVaultService {
        HTTPVaultService(transport: transport)
    }

    // MARK: Lifecycle

    @Test func theDetailCarriesHeartbeatAndRotationDetails() async throws {
        transport.answer("SecretDetail", """
        {"secret":{"id":"s1","name":"DB admin","canRead":true,"folderId":"f1","typeId":"t1","targetId":"tg",
          "expiresAt":null,"lastHeartbeatResult":"hostKeyMismatch","verifiedAt":"2026-10-28T12:00:00Z",
          "retired":false,"viewCount":1,"lastAccessedAt":null,"nextRotationAt":"2026-11-01T12:00:00Z",
          "lastRotationResult":"ok","rotatedAt":"2026-10-20T12:00:00Z","rotationOptOut":true,
          "heartbeatOptOut":false,"heartbeatBlockedReason":"no target"},
         "secretTypes":[{"id":"t1","name":"T","checkout":true,"heartbeat":true,"rotation":true,"fields":[]}],
         "activeLease":null,"folders":[]}
        """)
        transport.answer("SecretFields", #"{"secretFields":[]}"#)

        let detail = try await service.secret(id: "s1", .fixture)

        #expect(detail.summary.health == .unknown)
        #expect(detail.summary.heartbeatNote != nil)
        #expect(detail.lifecycle.rotation == .succeeded)
        #expect(detail.lifecycle.rotationOptOut)
        #expect(!detail.lifecycle.heartbeatOptOut)
        #expect(detail.lifecycle.heartbeatBlockedReason == "no target")
        #expect(detail.lifecycle.rotatedAt != nil)
        #expect(detail.type?.supportsRotation == true)
    }

    @Test func rotatingASecretNowSendsItsId() async throws {
        transport.answer("SecretRotate", #"{"rotateSecret":true}"#)

        try await service.rotate(secretID: "s1", .fixture)

        #expect(transport.operation(named: "SecretRotate")?.variables["secretId"] == .string("s1"))
    }

    @Test func retiringAndReinstatingASecretSendItsId() async throws {
        transport.answer("SecretRetire", #"{"retireSecret":{"id":"s1"}}"#)
        transport.answer("SecretRestore", #"{"restoreSecret":{"id":"s1"}}"#)

        try await service.retire(secretID: "s1", .fixture)
        try await service.reinstate(secretID: "s1", .fixture)

        #expect(transport.operation(named: "SecretRetire")?.variables["id"] == .string("s1"))
        #expect(transport.operation(named: "SecretRestore")?.variables["id"] == .string("s1"))
    }

    @Test func switchingAutomationOffSendsBothOptOutFlags() async throws {
        transport.answer("SecretSetAutomation", #"{"setSecretAutomation":{"id":"s1"}}"#)

        try await service.setAutomation(
            secretID: "s1", AutomationSetting(disableRotation: true, disableHeartbeat: false), .fixture
        )

        let variables = transport.operation(named: "SecretSetAutomation")?.variables
        #expect(variables?["secretId"] == .string("s1"))
        #expect(variables?["disableRotation"] == .bool(true))
        #expect(variables?["disableHeartbeat"] == .bool(false))
    }
}
