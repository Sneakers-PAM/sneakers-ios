// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// The GraphQL the app sends, the same operations the web app uses against the gateway.
nonisolated enum Operations {
    private static let leaseFields = "id secretId userId issuedAt expiresAt returned"
    private static let typeFields = "id name checkout fields { key label kind sensitive superSensitive }"

    static func dashboard(userID: String, limit: Int) -> GraphQLOperation {
        GraphQLOperation(
            name: "DashboardHome",
            query: """
            query DashboardHome($userId: String!, $limit: Int) {
              secretStats { total expiringSoon expired drift }
              topAccessedSecrets(limit: $limit) { id name folderId viewCount lastAccessedAt }
              activeLeasesForUser(userId: $userId) { \(leaseFields) }
            }
            """,
            variables: ["userId": .string(userID), "limit": .int(limit)]
        )
    }

    /// One aliased lookup per lease, so a whole list of lease names costs one request.
    static func leaseNames(for leases: [Lease]) -> GraphQLOperation {
        var declarations: [String] = []
        var selections: [String] = []
        var variables: [String: GraphQLValue] = [:]
        for (index, lease) in leases.enumerated() {
            declarations.append("$a\(index): ID!")
            selections.append("l\(index): secret(id: $a\(index)) { id name }")
            variables["a\(index)"] = .string(lease.secretId)
        }
        let arguments = declarations.joined(separator: ", ")
        let body = selections.joined(separator: " ")
        let query = "query DashboardLeaseNames(\(arguments)) { \(body) }"
        return GraphQLOperation(name: "DashboardLeaseNames", query: query, variables: variables)
    }

    static let folders = GraphQLOperation(
        name: "BrowseFolders",
        query: "query BrowseFolders { folders { id name parentId subtreeSecretCount } }"
    )

    static func contents(folderID: String) -> GraphQLOperation {
        GraphQLOperation(
            name: "BrowseSecrets",
            query: """
            query BrowseSecrets($folderId: String!, $includeRetired: Boolean) {
              secretsInFolder(folderId: $folderId, includeRetired: $includeRetired) {
                id name folderId typeId targetId lastHeartbeatResult retired canRead
              }
              secretTypes { \(typeFields) }
            }
            """,
            variables: ["folderId": .string(folderID), "includeRetired": .bool(false)]
        )
    }

    static func detail(id: String) -> GraphQLOperation {
        GraphQLOperation(
            name: "SecretDetail",
            query: """
            query SecretDetail($id: ID!, $secretId: String!) {
              secret(id: $id) {
                id name canRead folderId typeId targetId expiresAt lastHeartbeatResult verifiedAt retired
                viewCount lastAccessedAt nextRotationAt
              }
              secretTypes { \(typeFields) }
              activeLease(secretId: $secretId) { \(leaseFields) }
              folders { id name parentId }
            }
            """,
            variables: ["id": .string(id), "secretId": .string(id)]
        )
    }

    static func fields(id: String) -> GraphQLOperation {
        GraphQLOperation(
            name: "SecretFields",
            query: "query SecretFields($id: ID!) { secretFields(id: $id) { key value } }",
            variables: ["id": .string(id)]
        )
    }

    static func reveal(id: String, fieldKey: String) -> GraphQLOperation {
        GraphQLOperation(
            name: "SecretReveal",
            query: """
            mutation SecretReveal($id: ID!, $fieldKey: String!) {
              revealSecretField(id: $id, fieldKey: $fieldKey)
            }
            """,
            variables: ["id": .string(id), "fieldKey": .string(fieldKey)]
        )
    }

    static func checkout(secretID: String) -> GraphQLOperation {
        GraphQLOperation(
            name: "CheckoutsCheckout",
            query: """
            mutation CheckoutsCheckout($secretId: String!, $hours: Int) {
              checkoutSecret(secretId: $secretId, hours: $hours) { \(leaseFields) }
            }
            """,
            variables: ["secretId": .string(secretID)]
        )
    }

    static func checkin(secretID: String) -> GraphQLOperation {
        GraphQLOperation(
            name: "CheckoutsCheckin",
            query: "mutation CheckoutsCheckin($secretId: String!) { checkinSecret(secretId: $secretId) }",
            variables: ["secretId": .string(secretID)]
        )
    }
}
