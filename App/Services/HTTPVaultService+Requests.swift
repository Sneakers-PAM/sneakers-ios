// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// Reading the requests, deciding them, and the uses waiting for a decision.
extension HTTPVaultService {
    func requestsOverview(_ context: ServerContext) async throws -> RequestsOverview {
        let list = try await run(Operations.requestsList, as: ListResponse.self, in: context).approvalRequests
        let requests = list.map(\.request)
        guard !requests.isEmpty else {
            return RequestsOverview(requests: [], secretNames: [:], secretsIMayApprove: [], people: [:])
        }
        let secretIDs = Array(Set(requests.filter { !$0.kind.isMove || !$0.secretID.isEmpty }.map(\.secretID)))
            .filter { !$0.isEmpty }.sorted()
        var names: [String: String] = [:]
        var approvable: Set<String> = []
        if !secretIDs.isEmpty {
            let data = try await transport.execute(Operations.requestSecrets(ids: secretIDs), in: context)
            let answers = (try? JSONDecoder().decode([String: SecretAnswer].self, from: data)) ?? [:]
            for (index, id) in secretIDs.enumerated() {
                if let name = answers["n\(index)"]?.name {
                    names[id] = name
                }
                if answers["a\(index)"]?.approve == true {
                    approvable.insert(id)
                }
            }
        }
        let personIDs = Array(Set(requests.map(\.requestedByUserID))).sorted()
        let found = try await run(Operations.requestPeople(ids: personIDs), as: PeopleResponse.self, in: context)
        let people = Dictionary(found.resolveUserLabels.map { ($0.id, $0.name) }) { first, _ in first }
        return RequestsOverview(requests: requests, secretNames: names, secretsIMayApprove: approvable, people: people)
    }

    func resolve(requestID: String, approve: Bool, grantHours: Int?, _ context: ServerContext) async throws {
        let operation = Operations.resolve(requestID: requestID, approve: approve, grantHours: grantHours)
        _ = try await run(operation, as: ResolveResponse.self, in: context)
    }

    func comment(requestID: String, body: String, _ context: ServerContext) async throws {
        _ = try await run(Operations.comment(requestID: requestID, body: body), as: CommentResponse.self, in: context)
    }

    func usesToDecide(_ context: ServerContext) async throws -> [SecretUse] {
        try await run(Operations.usesToDecide, as: UsesToDecideResponse.self, in: context).secretUsesToDecide.map(\.use)
    }

    func myPendingUses(_ context: ServerContext) async throws -> [SecretUse] {
        try await run(Operations.myPendingUses, as: MyUsesResponse.self, in: context).pendingSecretUses.map(\.use)
    }

    func decideUse(id: String, approve: Bool, _ context: ServerContext) async throws {
        _ = try await run(Operations.decideUse(id: id, approve: approve), as: DecideResponse.self, in: context)
    }

    private struct WireComment: Decodable {
        let id: String
        let authorUserId: String
        let authorName: String?
        let body: String
        let createdAt: String?
    }

    private struct WireRequest: Decodable {
        let id: String
        let kind: String
        let secretId: String
        let folderName: String?
        let destParentName: String?
        let requestedByUserId: String
        let requestedAt: String?
        let reason: String?
        let status: String
        let resolvedAt: String?
        let resolvedByUserId: String?
        let resolvedByUserName: String?
        let comments: [WireComment]

        var request: ApprovalRequest {
            ApprovalRequest(
                id: id, kind: ApprovalKind(gateway: kind), secretID: secretId, folderName: folderName,
                destParentName: destParentName, requestedByUserID: requestedByUserId,
                requestedAt: requestedAt.flatMap(GatewayDate.parse), reason: reason,
                status: ApprovalStatus(gateway: status), resolvedAt: resolvedAt.flatMap(GatewayDate.parse),
                resolvedByUserID: resolvedByUserId, resolvedByName: resolvedByUserName,
                comments: comments.map {
                    ApprovalComment(
                        id: $0.id, authorID: $0.authorUserId, authorName: $0.authorName ?? "",
                        body: $0.body, createdAt: $0.createdAt.flatMap(GatewayDate.parse)
                    )
                }
            )
        }
    }

    private struct WireUse: Decodable {
        let id: String
        let secretName: String
        let fieldKey: String
        let state: String
        let expiresAtUnix: Int
        let purpose: String
        let requester: String
        let requestedBy: String
        let confirm: Bool
        let runId: String?

        var use: SecretUse {
            SecretUse(
                id: id, secretName: secretName, fieldKey: fieldKey, state: state,
                expiresAt: Date(timeIntervalSince1970: TimeInterval(expiresAtUnix)), purpose: purpose,
                requester: requester, requestedBy: requestedBy, confirm: confirm, runID: runId
            )
        }
    }

    private struct SecretAnswer: Decodable {
        let name: String?
        let approve: Bool?
    }

    private struct ListResponse: Decodable {
        let approvalRequests: [WireRequest]
    }

    private struct PeopleResponse: Decodable {
        let resolveUserLabels: [NameNode]
    }

    private struct ResolveResponse: Decodable {
        let resolveApproval: UpdatedSecret
    }

    private struct CommentResponse: Decodable {
        let addApprovalComment: UpdatedSecret
    }

    private struct UsesToDecideResponse: Decodable {
        let secretUsesToDecide: [WireUse]
    }

    private struct MyUsesResponse: Decodable {
        let pendingSecretUses: [WireUse]
    }

    /// A decision answers with the use's id and state, which nothing here needs.
    private struct Ack: Decodable {}

    private struct DecideResponse: Decodable {
        let decideSecretUse: Ack?
    }
}
