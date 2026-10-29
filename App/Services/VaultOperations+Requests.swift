// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// The requests people make and the uses waiting for a decision.
nonisolated extension Operations {
    private static let requestFields = """
    id kind secretId folderId folderName destParentId destParentName requestedByUserId requestedAt reason status
    resolvedAt resolvedByUserId resolvedByUserName comments { id authorUserId authorName body createdAt }
    """
    private static let useFields = """
    id secretName fieldKey state expiresAtUnix purpose requester requestedBy confirm runId reveal
    """

    static let requestsList = GraphQLOperation(
        name: "RequestsList",
        query: "query RequestsList { approvalRequests { \(requestFields) } }"
    )

    /// One query for every secret the requests name: its name, and whether I may approve for it.
    static func requestSecrets(ids: [String]) -> GraphQLOperation {
        var declarations: [String] = []
        var selections: [String] = []
        var variables: [String: GraphQLValue] = [:]
        for (index, id) in ids.enumerated() {
            declarations.append("$i\(index): ID!, $s\(index): String!")
            selections.append("n\(index): secret(id: $i\(index)) { id name }")
            selections.append("a\(index): mySecretAccess(secretId: $s\(index)) { approve }")
            variables["i\(index)"] = .string(id)
            variables["s\(index)"] = .string(id)
        }
        let arguments = declarations.joined(separator: ", ")
        let query = "query RequestsSecrets(\(arguments)) { \(selections.joined(separator: " ")) }"
        return GraphQLOperation(name: "RequestsSecrets", query: query, variables: variables)
    }

    static func requestPeople(ids: [String]) -> GraphQLOperation {
        GraphQLOperation(
            name: "RequestsPeople",
            query: "query RequestsPeople($ids: [String!]!) { resolveUserLabels(ids: $ids) { id name } }",
            variables: ["ids": .list(ids.map { .string($0) })]
        )
    }

    static func resolve(requestID: String, approve: Bool, grantHours: Int?) -> GraphQLOperation {
        var variables: [String: GraphQLValue] = ["id": .string(requestID), "approve": .bool(approve)]
        if let grantHours {
            variables["grantHours"] = .int(grantHours)
        }
        return GraphQLOperation(
            name: "RequestsResolve",
            query: """
            mutation RequestsResolve($id: ID!, $approve: Boolean!, $grantHours: Int) {
              resolveApproval(id: $id, approve: $approve, grantHours: $grantHours) { id }
            }
            """,
            variables: variables
        )
    }

    static func comment(requestID: String, body: String) -> GraphQLOperation {
        GraphQLOperation(
            name: "RequestsComment",
            query: """
            mutation RequestsComment($requestId: String!, $body: String!) {
              addApprovalComment(requestId: $requestId, body: $body) { id }
            }
            """,
            variables: ["requestId": .string(requestID), "body": .string(body)]
        )
    }

    static let usesToDecide = GraphQLOperation(
        name: "ApprovalsUsesToDecide",
        query: "query ApprovalsUsesToDecide { secretUsesToDecide { \(useFields) } }"
    )

    static let myPendingUses = GraphQLOperation(
        name: "RequestsMyUses",
        query: "query RequestsMyUses { pendingSecretUses { \(useFields) } }"
    )

    static func decideUse(id: String, approve: Bool) -> GraphQLOperation {
        GraphQLOperation(
            name: "ApprovalsDecideUse",
            query: """
            mutation ApprovalsDecideUse($id: ID!, $approve: Boolean!) {
              decideSecretUse(id: $id, approve: $approve) { id state }
            }
            """,
            variables: ["id": .string(id), "approve": .bool(approve)]
        )
    }
}
