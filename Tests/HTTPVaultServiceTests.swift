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

    // MARK: Access and edit

    private let accessJSON = """
    {"read":true,"reveal":true,"manage":true,"approve":false,"informed":false,"manageRuleset":false}
    """

    @Test func aFoldersAccessIsAskedForByItsId() async throws {
        transport.answer("BrowseFolderAccess", #"{"myFolderAccess":\#(accessJSON)}"#)

        let access = try await service.access(forFolder: "f1", .fixture)

        #expect(access.manage && !access.approve)
        #expect(transport.operation(named: "BrowseFolderAccess")?.variables["folderId"] == .string("f1"))
    }

    @Test func aSecretsAccessIsAskedForByItsId() async throws {
        transport.answer("SecretAccess", #"{"mySecretAccess":\#(accessJSON)}"#)

        let access = try await service.access(forSecret: "s1", .fixture)

        #expect(access.read && access.reveal)
        #expect(transport.operation(named: "SecretAccess")?.variables["secretId"] == .string("s1"))
    }

    @Test func savingSendsOnlyTheNameAndTheFieldsGiven() async throws {
        transport.answer("EditorsUpdateSecret", #"{"updateSecret":{"id":"s1"}}"#)
        let change = SecretChange(name: "New name", fields: ["username": "bob", "notes": "line 1\nline 2"])

        try await service.update(secretID: "s1", change, .fixture)

        let operation = try #require(transport.operation(named: "EditorsUpdateSecret"))
        #expect(operation.variables["id"] == .string("s1"))
        guard case let .object(input)? = operation.variables["input"] else {
            Issue.record("the input is missing")
            return
        }
        #expect(input["name"] == .string("New name"))
        guard case let .list(fields)? = input["fields"] else {
            Issue.record("the fields are missing")
            return
        }
        let pairs = fields.compactMap { value -> [String: GraphQLValue]? in
            if case let .object(pair) = value {
                pair
            } else {
                nil
            }
        }
        #expect(pairs.count == 2)
        #expect(pairs.contains { $0["key"] == .string("username") && $0["value"] == .string("bob") })
    }

    @Test func aChangeWithNoNameLeavesItOut() async throws {
        transport.answer("EditorsUpdateSecret", #"{"updateSecret":{"id":"s1"}}"#)

        try await service.update(secretID: "s1", SecretChange(name: nil, fields: ["a": "b"]), .fixture)

        guard case let .object(input)? = transport.operation(named: "EditorsUpdateSecret")?.variables["input"] else {
            Issue.record("the input is missing")
            return
        }
        #expect(input["name"] == nil)
    }

    @Test func aRefusedSaveSaysWhy() async {
        transport.fail("EditorsUpdateSecret", .noAccess)

        await #expect(throws: VaultError.noAccess) {
            try await service.update(secretID: "s1", SecretChange(name: "x", fields: [:]), .fixture)
        }
    }

    // MARK: History

    @Test func theVersionsOfASecretAreListedWithoutValues() async throws {
        transport.answer("SecretVersions", """
        {"secretVersions":[{"versionNo":2,"createdBy":"u1","createdByName":"Alice","createdAt":"2026-10-28T12:00:00Z",
          "active":true,"fieldKeys":["password"],"changedFieldKeys":["password"],"changeLabel":null},
         {"versionNo":1,"createdBy":"u1","createdByName":"Alice","createdAt":"2026-10-27T12:00:00Z",
          "active":false,"fieldKeys":["password"],"changedFieldKeys":["password"],"changeLabel":null}]}
        """)

        let versions = try await service.versions(secretID: "s1", .fixture)

        #expect(versions.map(\.versionNo) == [2, 1])
        #expect(versions.first?.active == true)
        #expect(versions.first?.createdByName == "Alice")
        #expect(transport.operation(named: "SecretVersions")?.variables["secretId"] == .string("s1"))
    }

    @Test func anOldValueIsRevealedByVersionAndField() async throws {
        transport.answer("SecretRevealVersion", #"{"revealSecretVersionField":"old-value"}"#)

        let value = try await service.revealVersion(
            RevealKey(secretID: "s1", fieldKey: "password", versionNo: 2),
            .fixture
        )

        #expect(value == "old-value")
        let variables = transport.operation(named: "SecretRevealVersion")?.variables
        #expect(variables?["versionNo"] == .int(2))
        #expect(variables?["fieldKey"] == .string("password"))
    }

    @Test func restoringAVersionSendsTheSecretAndTheVersion() async throws {
        transport.answer("SecretRestoreVersion", #"{"restoreSecretVersion":{"id":"s1"}}"#)

        try await service.restore(secretID: "s1", versionNo: 2, .fixture)

        let variables = transport.operation(named: "SecretRestoreVersion")?.variables
        #expect(variables?["secretId"] == .string("s1"))
        #expect(variables?["versionNo"] == .int(2))
    }

    @Test func theRecoveryRoleBeingNeededIsItsOwnRefusal() async {
        transport.fail("SecretRevealVersion", .recoveryRoleRequired)

        await #expect(throws: VaultError.recoveryRoleRequired) {
            try await service.revealVersion(RevealKey(secretID: "s1", fieldKey: "password", versionNo: 1), .fixture)
        }
    }
}
