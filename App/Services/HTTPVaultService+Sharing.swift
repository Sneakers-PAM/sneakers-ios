// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// Reading and saving who can access a secret or folder.
extension HTTPVaultService {
    func ruleset(forSecret secretID: String, _ context: ServerContext) async throws -> Ruleset {
        let wire = try await run(
            Operations.secretRuleset(secretID: secretID), as: SecretRulesetResponse.self, in: context
        ).secretRuleset
        return try await build(rules: wire.rules, inherited: wire.inherited, owners: [], context)
    }

    func ruleset(forFolder folderID: String, _ context: ServerContext) async throws -> Ruleset {
        let wire = try await run(
            Operations.folderRuleset(folderID: folderID), as: FolderRulesetResponse.self, in: context
        ).folderRuleset
        return try await build(rules: wire.rules, inherited: wire.inherited, owners: wire.owners, context)
    }

    func saveRules(forSecret secretID: String, _ rules: [AccessRule], _ context: ServerContext) async throws {
        _ = try await run(
            Operations.saveSecretRules(secretID: secretID, rules: rules), as: SaveSecretRulesResponse.self, in: context
        )
    }

    func saveRules(forFolder folderID: String, _ update: RulesUpdate, _ context: ServerContext) async throws {
        let operation = Operations.saveFolderRules(folderID: folderID, rules: update.rules, owners: update.owners)
        _ = try await run(operation, as: SaveFolderRulesResponse.self, in: context)
    }

    func searchPeople(_ query: String, _ context: ServerContext) async throws -> [Person] {
        try await run(Operations.searchUsers(query: query), as: SearchResponse.self, in: context).searchUsers
    }

    private func build(
        rules: [WireRule], inherited: [WireInherited], owners: [String], _ context: ServerContext
    ) async throws -> Ruleset {
        let mine = rules.map(\.accessRule)
        let above = inherited.map { InheritedRule(rule: $0.rule.accessRule, fromFolderName: $0.fromFolderName) }
        let ids = Set(
            (mine + above.map(\.rule)).filter { $0.subjectKind == "user" }.map(\.subjectName) + owners
        ).sorted()
        var labels: [String: String] = [:]
        if !ids.isEmpty {
            let found = try await run(Operations.userLabels(ids: ids), as: LabelsResponse.self, in: context)
            labels = Dictionary(
                found.resolveUserLabels.map { ($0.id, $0.name) },
                uniquingKeysWith: { first, _ in first }
            )
        }
        return Ruleset(rules: mine, inherited: above, owners: owners, labels: labels)
    }

    private struct WireGrant: Decodable {
        let action: String
        let value: String
    }

    private struct WireRule: Decodable {
        let id: String
        let subjectKind: String
        let subjectName: String
        let subjectId: String?
        let grants: [WireGrant]

        var accessRule: AccessRule {
            let cells = grants.compactMap { grant -> RuleGrant? in
                guard let action = RuleAction(gatewayKey: grant.action), let value = GrantValue(rawValue: grant.value)
                else { return nil }
                return RuleGrant(action: action, value: value)
            }
            return AccessRule(
                id: id,
                subjectKind: subjectKind,
                subjectName: subjectName,
                subjectId: subjectId,
                grants: cells
            )
        }
    }

    private struct WireInherited: Decodable {
        let fromFolderName: String
        let rule: WireRule
    }

    private struct WireSecretRuleset: Decodable {
        let rules: [WireRule]
        let inherited: [WireInherited]
    }

    private struct WireFolderRuleset: Decodable {
        let owners: [String]
        let rules: [WireRule]
        let inherited: [WireInherited]
    }

    private struct SecretRulesetResponse: Decodable {
        let secretRuleset: WireSecretRuleset
    }

    private struct FolderRulesetResponse: Decodable {
        let folderRuleset: WireFolderRuleset
    }

    private struct LabelsResponse: Decodable {
        let resolveUserLabels: [NameNode]
    }

    private struct SearchResponse: Decodable {
        let searchUsers: [Person]
    }

    /// A save answers with the id of what it saved, which nothing here needs.
    private struct Ack: Decodable {}

    private struct SaveSecretRulesResponse: Decodable {
        let setSecretRuleset: Ack?
    }

    private struct SaveFolderRulesResponse: Decodable {
        let setFolderRuleset: Ack?
    }
}
