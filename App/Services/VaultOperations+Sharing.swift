// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// Who can access a secret or folder: the rules, the people they name, and saving them.
nonisolated extension Operations {
    private static let ruleFields = "id order subjectKind subjectName subjectId grants { action value }"
    private static let inheritedFields = "fromFolderId fromFolderName rule { \(ruleFields) }"

    static func secretRuleset(secretID: String) -> GraphQLOperation {
        GraphQLOperation(
            name: "SharingSecretRuleset",
            query: """
            query SharingSecretRuleset($secretId: String!) {
              secretRuleset(secretId: $secretId) {
                secretId rules { \(ruleFields) } inherited { \(inheritedFields) }
              }
            }
            """,
            variables: ["secretId": .string(secretID)]
        )
    }

    static func folderRuleset(folderID: String) -> GraphQLOperation {
        GraphQLOperation(
            name: "SharingFolderRuleset",
            query: """
            query SharingFolderRuleset($folderId: String!) {
              folderRuleset(folderId: $folderId) {
                folderId owners rules { \(ruleFields) } inherited { \(inheritedFields) }
              }
            }
            """,
            variables: ["folderId": .string(folderID)]
        )
    }

    static func userLabels(ids: [String]) -> GraphQLOperation {
        GraphQLOperation(
            name: "SharingUserLabels",
            query: "query SharingUserLabels($ids: [String!]!) { resolveUserLabels(ids: $ids) { id name } }",
            variables: ["ids": .list(ids.map { .string($0) })]
        )
    }

    static func searchUsers(query: String) -> GraphQLOperation {
        GraphQLOperation(
            name: "SharingSearchUsers",
            query: """
            query SharingSearchUsers($query: String!) { searchUsers(query: $query, limit: 8) { id name username } }
            """,
            variables: ["query": .string(query)]
        )
    }

    static func ruleInput(_ rule: AccessRule) -> GraphQLValue {
        var input: [String: GraphQLValue] = ["subjectKind": .string(rule.subjectKind)]
        input["subjectName"] = .string(rule.subjectName)
        if let subjectId = rule.subjectId {
            input["subjectId"] = .string(subjectId)
        }
        input["grants"] = .list(rule.grants.map { grant in
            .object(["action": .string(grant.action.gatewayKey), "value": .string(grant.value.rawValue)])
        })
        return .object(input)
    }

    static func saveSecretRules(secretID: String, rules: [AccessRule]) -> GraphQLOperation {
        GraphQLOperation(
            name: "SharingSetSecretRuleset",
            query: """
            mutation SharingSetSecretRuleset($secretId: String!, $rules: [RaciRuleInput!]!) {
              setSecretRuleset(secretId: $secretId, rules: $rules) { secretId }
            }
            """,
            variables: ["secretId": .string(secretID), "rules": .list(rules.map(ruleInput))]
        )
    }

    static func saveFolderRules(folderID: String, rules: [AccessRule], owners: [String]) -> GraphQLOperation {
        var variables: [String: GraphQLValue] = ["folderId": .string(folderID)]
        variables["owners"] = .list(owners.map { .string($0) })
        variables["rules"] = .list(rules.map(ruleInput))
        return GraphQLOperation(
            name: "SharingSetFolderRuleset",
            query: """
            mutation SharingSetFolderRuleset($folderId: String!, $owners: [String!]!, $rules: [RaciRuleInput!]!) {
              setFolderRuleset(folderId: $folderId, owners: $owners, rules: $rules) { folderId }
            }
            """,
            variables: variables
        )
    }

    static let groups = GraphQLOperation(
        name: "SharingGroups",
        query: "query SharingGroups { groups { id name } }"
    )

    private static let decisionFields = """
    read readReason reveal revealReason manage manageReason approve approveReason informed informedReason
    """

    static func preview(_ request: PreviewRequest) -> GraphQLOperation {
        var variables: [String: GraphQLValue] = ["userId": .string(request.userID)]
        variables["draftRules"] = .list(request.rules.map(ruleInput))
        switch request.target {
        case let .secret(id):
            variables["secretId"] = .string(id)
            return GraphQLOperation(
                name: "SharingSimulateSecret",
                query: """
                query SharingSimulateSecret($secretId: String!, $userId: String!, $draftRules: [RaciRuleInput!]!) {
                  simulateSecret(secretId: $secretId, userId: $userId, draftRules: $draftRules) { \(decisionFields) }
                }
                """,
                variables: variables
            )
        case let .folder(id):
            variables["folderId"] = .string(id)
            return GraphQLOperation(
                name: "SharingSimulateFolder",
                query: """
                query SharingSimulateFolder($folderId: String!, $userId: String!, $draftRules: [RaciRuleInput!]!) {
                  simulateFolder(folderId: $folderId, userId: $userId, draftRules: $draftRules) { \(decisionFields) }
                }
                """,
                variables: variables
            )
        }
    }
}
