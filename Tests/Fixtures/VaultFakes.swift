// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Sneakers_PAM

/// A transport that answers each operation by name with canned `data` JSON, and remembers what it was asked.
final class FakeGraphQLTransport: GraphQLTransport, @unchecked Sendable {
    private(set) var operations: [GraphQLOperation] = []
    var answers: [String: Result<String, VaultError>] = [:]

    func answer(_ name: String, _ json: String) {
        answers[name] = .success(json)
    }

    func fail(_ name: String, _ error: VaultError) {
        answers[name] = .failure(error)
    }

    func operation(named name: String) -> GraphQLOperation? {
        operations.last { $0.name == name }
    }

    func execute(_ operation: GraphQLOperation, in _: ServerContext) async throws -> Data {
        operations.append(operation)
        guard let answer = answers[operation.name] else { throw VaultError.unexpected }
        return try Data(answer.get().utf8)
    }
}

extension ServerContext {
    static var fixture: ServerContext {
        ServerContext(server: ServerURL.fixture, session: .fixture(cookie: "abc123", csrf: "tok", user: "me"))
    }
}

/// A vault that answers from scripted values and counts calls. It never records a revealed value.
final class FakeVaultService: VaultServicing, @unchecked Sendable {
    var dashboardResult: Result<DashboardData, VaultError> = .failure(.unexpected)
    var foldersResult: Result<[Folder], VaultError> = .success([])
    var contentsResult: Result<FolderContents, VaultError> = .success(FolderContents(secrets: [], types: []))
    var detailResult: Result<SecretDetail, VaultError> = .failure(.notFound)
    var revealResults: [Result<String, VaultError>] = []
    var checkoutResult: Result<Lease, VaultError> = .failure(.unexpected)
    var checkinResult: Result<Void, VaultError> = .success(())

    var folderAccessResult: Result<Access, VaultError> = .success(.fixtureFull)
    var secretAccessResult: Result<Access, VaultError> = .success(.fixtureFull)
    var updateResult: Result<Void, VaultError> = .success(())

    var versionsResult: Result<[SecretVersion], VaultError> = .success([])
    var versionRevealResults: [Result<String, VaultError>] = []
    var restoreResults: [Result<Void, VaultError>] = []

    var lifecycleResult: Result<Void, VaultError> = .success(())

    var folderResult: Result<Folder, VaultError> = .success(
        Folder(id: "new", name: "New", parentId: nil, subtreeSecretCount: 0)
    )
    var folderActionResult: Result<Void, VaultError> = .success(())
    var typesResult: Result<[SecretType], VaultError> = .success([])
    var createdSecretID = "s-new"

    private(set) var createdFolders: [(parentID: String?, name: String)] = []
    private(set) var renamedFolders: [(id: String, name: String)] = []
    private(set) var movedFolders: [(id: String, parentID: String?)] = []
    private(set) var movedSecrets: [(id: String, folderID: String)] = []
    private(set) var moveRequests: [MoveRequest] = []
    private(set) var createdSecrets: [NewSecret] = []
    var rulesetResult: Result<Ruleset, VaultError> = .success(Ruleset(rules: [], inherited: [], owners: []))
    var saveRulesResult: Result<Void, VaultError> = .success(())
    var peopleResult: Result<[Person], VaultError> = .success([])

    private(set) var savedSecretRules: [(secretID: String, rules: [AccessRule])] = []
    private(set) var savedFolderRules: [(folderID: String, update: RulesUpdate)] = []
    var prepareResults: [Result<HeldReveal, VaultError>] = []
    var redeemResults: [Result<String, VaultError>] = []

    var overviewResult: Result<RequestsOverview, VaultError> = .success(
        RequestsOverview(requests: [], secretNames: [:], secretsIMayApprove: [], people: [:])
    )
    var usesToDecideResult: Result<[SecretUse], VaultError> = .success([])
    var myUsesResult: Result<[SecretUse], VaultError> = .success([])
    var decisionResult: Result<Void, VaultError> = .success(())

    private(set) var resolutions: [Resolution] = []
    private(set) var comments: [(requestID: String, body: String)] = []
    private(set) var useDecisions: [(id: String, approve: Bool)] = []
    var requestAccessResult: Result<Void, VaultError> = .success(())

    private(set) var accessRequests: [(secretID: String, reason: String)] = []
    private(set) var prepared: [PreparedReveal] = []
    private(set) var redeemed: [String] = []
    private(set) var rotations: [String] = []
    private(set) var retirements: [String] = []
    private(set) var reinstatements: [String] = []
    private(set) var automations: [AutomationRequest] = []
    private(set) var versionRevealRequests: [RevealKey] = []
    private(set) var restores: [(secretID: String, versionNo: Int)] = []
    private(set) var updates: [(secretID: String, change: SecretChange)] = []
    private(set) var dashboardCalls = 0
    private(set) var folderCalls = 0
    private(set) var contentsCalls: [String] = []
    private(set) var revealRequests: [(secretID: String, fieldKey: String)] = []
    private(set) var checkouts = 0
    private(set) var checkins = 0

    func dashboard(_: ServerContext) async throws -> DashboardData {
        dashboardCalls += 1
        return try dashboardResult.get()
    }

    func folders(_: ServerContext) async throws -> [Folder] {
        folderCalls += 1
        return try foldersResult.get()
    }

    func contents(ofFolder folderID: String, _: ServerContext) async throws -> FolderContents {
        contentsCalls.append(folderID)
        return try contentsResult.get()
    }

    func secret(id _: String, _: ServerContext) async throws -> SecretDetail {
        try detailResult.get()
    }

    func reveal(secretID: String, fieldKey: String, _: ServerContext) async throws -> String {
        revealRequests.append((secretID, fieldKey))
        guard !revealResults.isEmpty else { throw VaultError.unexpected }
        return try revealResults.removeFirst().get()
    }

    func checkout(secretID _: String, _: ServerContext) async throws -> Lease {
        checkouts += 1
        return try checkoutResult.get()
    }

    func checkin(secretID _: String, _: ServerContext) async throws {
        checkins += 1
        try checkinResult.get()
    }

    func access(forFolder _: String, _: ServerContext) async throws -> Access {
        try folderAccessResult.get()
    }

    func access(forSecret _: String, _: ServerContext) async throws -> Access {
        try secretAccessResult.get()
    }

    func update(secretID: String, _ change: SecretChange, _: ServerContext) async throws {
        updates.append((secretID, change))
        try updateResult.get()
    }

    func rotate(secretID: String, _: ServerContext) async throws {
        rotations.append(secretID)
        try lifecycleResult.get()
    }

    func retire(secretID: String, _: ServerContext) async throws {
        retirements.append(secretID)
        try lifecycleResult.get()
    }

    func reinstate(secretID: String, _: ServerContext) async throws {
        reinstatements.append(secretID)
        try lifecycleResult.get()
    }

    func setAutomation(secretID: String, _ setting: AutomationSetting, _: ServerContext) async throws {
        automations.append(AutomationRequest(secretID: secretID, setting: setting))
        try lifecycleResult.get()
    }

    func ruleset(forSecret _: String, _: ServerContext) async throws -> Ruleset {
        try rulesetResult.get()
    }

    func ruleset(forFolder _: String, _: ServerContext) async throws -> Ruleset {
        try rulesetResult.get()
    }

    func saveRules(forSecret secretID: String, _ rules: [AccessRule], _: ServerContext) async throws {
        savedSecretRules.append((secretID, rules))
        try saveRulesResult.get()
    }

    func saveRules(forFolder folderID: String, _ update: RulesUpdate, _: ServerContext) async throws {
        savedFolderRules.append((folderID, update))
        try saveRulesResult.get()
    }

    func searchPeople(_: String, _: ServerContext) async throws -> [Person] {
        try peopleResult.get()
    }

    func createFolder(parentID: String?, name: String, _: ServerContext) async throws -> Folder {
        createdFolders.append((parentID, name))
        return try folderResult.get()
    }

    func renameFolder(id: String, name: String, _: ServerContext) async throws {
        renamedFolders.append((id, name))
        try folderActionResult.get()
    }

    func moveFolder(id: String, to parentID: String?, _: ServerContext) async throws {
        movedFolders.append((id, parentID))
        try folderActionResult.get()
    }

    func moveSecret(id: String, to folderID: String, _: ServerContext) async throws {
        movedSecrets.append((id, folderID))
        try folderActionResult.get()
    }

    func requestMove(_ request: MoveRequest, _: ServerContext) async throws {
        moveRequests.append(request)
        try folderActionResult.get()
    }

    func secretTypes(_: ServerContext) async throws -> [SecretType] {
        try typesResult.get()
    }

    func createSecret(_ secret: NewSecret, _: ServerContext) async throws -> String {
        createdSecrets.append(secret)
        try folderActionResult.get()
        return createdSecretID
    }

    func requestsOverview(_: ServerContext) async throws -> RequestsOverview {
        try overviewResult.get()
    }

    func resolve(requestID: String, approve: Bool, grantHours: Int?, _: ServerContext) async throws {
        resolutions.append(Resolution(requestID: requestID, approve: approve, grantHours: grantHours))
        try decisionResult.get()
    }

    func comment(requestID: String, body: String, _: ServerContext) async throws {
        comments.append((requestID, body))
        try decisionResult.get()
    }

    func usesToDecide(_: ServerContext) async throws -> [SecretUse] {
        try usesToDecideResult.get()
    }

    func myPendingUses(_: ServerContext) async throws -> [SecretUse] {
        try myUsesResult.get()
    }

    func decideUse(id: String, approve: Bool, _: ServerContext) async throws {
        useDecisions.append((id, approve))
        try decisionResult.get()
    }

    func requestAccess(secretID: String, reason: String, _: ServerContext) async throws {
        accessRequests.append((secretID, reason))
        try requestAccessResult.get()
    }

    func prepareReveal(_ key: RevealKey, runID: String, _: ServerContext) async throws -> HeldReveal {
        prepared.append(PreparedReveal(secretID: key.secretID, fieldKey: key.fieldKey, runID: runID))
        guard !prepareResults.isEmpty else { throw VaultError.unexpected }
        return try prepareResults.removeFirst().get()
    }

    func redeemReveal(useID: String, _: ServerContext) async throws -> String {
        redeemed.append(useID)
        guard !redeemResults.isEmpty else { throw VaultError.approvalPending }
        return try redeemResults.removeFirst().get()
    }

    func versions(secretID _: String, _: ServerContext) async throws -> [SecretVersion] {
        try versionsResult.get()
    }

    func revealVersion(_ key: RevealKey, _: ServerContext) async throws -> String {
        versionRevealRequests.append(key)
        guard !versionRevealResults.isEmpty else { throw VaultError.unexpected }
        return try versionRevealResults.removeFirst().get()
    }

    func restore(secretID: String, versionNo: Int, _: ServerContext) async throws {
        restores.append((secretID, versionNo))
        guard !restoreResults.isEmpty else { return }
        try restoreResults.removeFirst().get()
    }
}

struct Resolution: Equatable {
    let requestID: String
    let approve: Bool
    let grantHours: Int?
}

struct PreparedReveal: Equatable {
    let secretID: String
    let fieldKey: String
    let runID: String
}

struct AutomationRequest: Equatable {
    let secretID: String
    let setting: AutomationSetting
}

extension Access {
    static var fixtureFull: Access {
        Access(read: true, reveal: true, manage: true, approve: false, informed: false, manageRuleset: false)
    }

    static var fixtureReadOnly: Access {
        Access(read: true, reveal: true, manage: false, approve: false, informed: false, manageRuleset: false)
    }
}

extension SecretSummary {
    static func fixture(
        id: String = "s1",
        name: String = "DB admin",
        folder: String? = "f1",
        type: String? = "t1",
        canRead: Bool? = true
    ) -> SecretSummary {
        SecretSummary(
            id: id, name: name, folderId: folder, typeId: type, targetId: "tg1", lastHeartbeatResult: "ok",
            retired: false, canRead: canRead, viewCount: 3, lastAccessedAt: nil
        )
    }
}

extension SecretType {
    static var databaseFixture: SecretType {
        let username = FieldDefinition(
            key: "username",
            label: "Username",
            kind: "text",
            sensitive: false,
            superSensitive: false
        )
        let password = FieldDefinition(
            key: "password",
            label: "Password",
            kind: "text",
            sensitive: true,
            superSensitive: false
        )
        return SecretType(id: "t1", name: "Database account", checkout: true, fields: [username, password])
    }
}
