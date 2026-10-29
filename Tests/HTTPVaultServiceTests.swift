// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Sneakers_PAM
import Testing

struct HTTPVaultServiceTests {
    private let transport = FakeGraphQLTransport()
    private var service: HTTPVaultService {
        HTTPVaultService(transport: transport)
    }

    private let emptyDashboard = """
    {"secretStats":{"total":0,"expiringSoon":0,"expired":0,"drift":0},"topAccessedSecrets":[],"activeLeasesForUser":[]}
    """

    private let leaseJSON = """
    {"id":"l1","secretId":"s9","issuedAt":"2026-10-28T12:00:00Z","expiresAt":"2026-10-28T13:59:00Z"}
    """

    // MARK: Dashboard

    @Test func theDashboardJoinsTheCountsTheTopSecretsAndTheLeaseNames() async throws {
        transport.answer("DashboardHome", """
        {"secretStats":{"total":148,"expiringSoon":12,"expired":2,"drift":3},
         "topAccessedSecrets":[{"id":"s1","name":"DB admin","folderId":"f2","viewCount":42,"lastAccessedAt":null}],
         "activeLeasesForUser":[\(leaseJSON)]}
        """)
        transport.answer("DashboardLeaseNames", #"{"l0":{"id":"s9","name":"Acme VPN"}}"#)

        let data = try await service.dashboard(.fixture)

        #expect(data.stats == SecretStats(total: 148, expiringSoon: 12, expired: 2, drift: 3))
        #expect(data.topSecrets.map(\.name) == ["DB admin"])
        #expect(data.leases.map(\.secretName) == ["Acme VPN"])
        #expect(data.leases.first?.lease.secretId == "s9")
    }

    @Test func theDashboardAsksForTheSignedInUsersLeasesAndFiveTopSecrets() async throws {
        transport.answer("DashboardHome", emptyDashboard)

        _ = try await service.dashboard(.fixture)

        let operation = try #require(transport.operation(named: "DashboardHome"))
        #expect(operation.variables["userId"] == .string("me"))
        #expect(operation.variables["limit"] == .int(5))
        #expect(transport.operation(named: "DashboardLeaseNames") == nil)
    }

    @Test func aLeaseWhoseNameCannotBeFoundStillShowsWithAPlainName() async throws {
        transport.answer("DashboardHome", """
        {"secretStats":{"total":1,"expiringSoon":0,"expired":0,"drift":0},"topAccessedSecrets":[],
         "activeLeasesForUser":[\(leaseJSON)]}
        """)
        transport.answer("DashboardLeaseNames", #"{"l0":null}"#)

        let data = try await service.dashboard(.fixture)

        #expect(data.leases.first?.secretName == "A secret")
    }

    // MARK: Folders and secrets

    @Test func foldersDecodeFromTheFlatList() async throws {
        transport.answer("BrowseFolders", """
        {"folders":[{"id":"f1","name":"Platform","parentId":null},{"id":"f2","name":"Databases","parentId":"f1"}]}
        """)

        let result = try await service.folders(.fixture)

        #expect(result.map(\.id) == ["f1", "f2"])
        #expect(result.last?.parentId == "f1")
    }

    @Test func aFoldersContentsAreItsSecretsAndTheTypesThatDescribeThem() async throws {
        transport.answer("BrowseSecrets", """
        {"secretsInFolder":[{"id":"s1","name":"DB admin","folderId":"f2","typeId":"t1","targetId":"tg1",
           "lastHeartbeatResult":"ok","retired":false,"canRead":true}],
         "secretTypes":[{"id":"t1","name":"Database account","checkout":true,
           "fields":[{"key":"password","label":"Password","kind":"password","sensitive":true,"superSensitive":false}]}]}
        """)

        let contents = try await service.contents(ofFolder: "f2", .fixture)

        #expect(contents.secrets.map(\.name) == ["DB admin"])
        #expect(contents.types.first?.primarySensitiveFieldKey == "password")
        let operation = try #require(transport.operation(named: "BrowseSecrets"))
        #expect(operation.variables["folderId"] == .string("f2"))
        #expect(operation.variables["includeRetired"] == .bool(false))
    }

    // MARK: Secret detail

    private let detailBase = """
    {"secret":{"id":"s1","name":"DB admin","canRead":true,"folderId":"f2","typeId":"t1","targetId":"tg1",
      "expiresAt":"2026-12-01T00:00:00Z","lastHeartbeatResult":"ok","verifiedAt":"2026-10-28T11:00:00Z","retired":false,
      "viewCount":3,"lastAccessedAt":null,"nextRotationAt":null},
     "secretTypes":[{"id":"t1","name":"Database account","checkout":true,
       "fields":[{"key":"username","label":"Username","kind":"text","sensitive":false,"superSensitive":false},
                 {"key":"password","label":"Password","kind":"password","sensitive":true,"superSensitive":false}]}],
     "activeLease":{"id":"l1","secretId":"s1","userId":"u2","issuedAt":"2026-10-28T12:00:00Z",
       "expiresAt":"2026-10-28T14:00:00Z"},
     "folders":[{"id":"f1","name":"Platform","parentId":null},{"id":"f2","name":"Databases","parentId":"f1"}]}
    """

    @Test func aReadableSecretShowsItsSafeValuesItsPathItsTypeAndWhoHoldsIt() async throws {
        transport.answer("SecretDetail", detailBase)
        transport.answer("SecretFields", #"{"secretFields":[{"key":"username","value":"app_admin"}]}"#)

        let detail = try await service.secret(id: "s1", .fixture)

        #expect(detail.summary.name == "DB admin")
        #expect(detail.type?.name == "Database account")
        #expect(detail.values == ["username": "app_admin"])
        #expect(detail.lease?.userId == "u2")
        #expect(detail.folderPath == "Platform / Databases")
        #expect(detail.expiresAt != nil)
    }

    @Test func aSecretTheUserCannotReadDoesNotAskForItsFields() async throws {
        let locked = detailBase.replacingOccurrences(of: #""canRead":true"#, with: #""canRead":false"#)
        transport.answer("SecretDetail", locked)

        let detail = try await service.secret(id: "s1", .fixture)

        #expect(detail.values.isEmpty)
        #expect(!detail.summary.isReadable)
        #expect(transport.operation(named: "SecretFields") == nil)
    }

    @Test func aSecretThatIsNotThereIsNotFound() async {
        transport.answer("SecretDetail", #"{"secret":null,"secretTypes":[],"activeLease":null,"folders":[]}"#)

        await #expect(throws: VaultError.notFound) { try await service.secret(id: "s1", .fixture) }
    }

    // MARK: Reveal, check out and in

    @Test func revealingAFieldReturnsItsValueAndAsksForThatFieldOnly() async throws {
        transport.answer("SecretReveal", #"{"revealSecretField":"a-value"}"#)

        let value = try await service.reveal(secretID: "s1", fieldKey: "password", .fixture)

        #expect(value == "a-value")
        let operation = try #require(transport.operation(named: "SecretReveal"))
        #expect(operation.variables["id"] == .string("s1"))
        #expect(operation.variables["fieldKey"] == .string("password"))
    }

    @Test func aRevealThatNeedsAFreshFactorSaysSo() async {
        transport.fail("SecretReveal", .stepUpRequired)

        await #expect(throws: VaultError.stepUpRequired) {
            try await service.reveal(secretID: "s1", fieldKey: "password", .fixture)
        }
    }

    @Test func checkingOutReturnsTheLease() async throws {
        transport.answer("CheckoutsCheckout", """
        {"checkoutSecret":{"id":"l1","secretId":"s1","userId":"me","issuedAt":"2026-10-28T12:00:00Z",
          "expiresAt":"2026-10-28T14:00:00Z","returned":false}}
        """)

        let lease = try await service.checkout(secretID: "s1", .fixture)

        #expect(lease.secretId == "s1")
        #expect(transport.operation(named: "CheckoutsCheckout")?.variables["secretId"] == .string("s1"))
    }

    @Test func checkingInAsksTheServerToReturnTheLease() async throws {
        transport.answer("CheckoutsCheckin", #"{"checkinSecret":true}"#)

        try await service.checkin(secretID: "s1", .fixture)

        #expect(transport.operation(named: "CheckoutsCheckin")?.variables["secretId"] == .string("s1"))
    }

    @Test func aCheckoutThatSomeoneElseHoldsIsRefused() async {
        transport.fail("CheckoutsCheckout", .leaseHeld)

        await #expect(throws: VaultError.leaseHeld) { try await service.checkout(secretID: "s1", .fixture) }
    }
}
