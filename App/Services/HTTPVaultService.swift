// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// Reads the vault through the gateway's human GraphQL API, with the same operations the web app uses.
nonisolated struct HTTPVaultService: VaultServicing {
    var transport: GraphQLTransport = HTTPGraphQLTransport()

    private static let topSecretLimit = 5

    // MARK: VaultServicing

    func dashboard(_ context: ServerContext) async throws -> DashboardData {
        let home = try await run(Operations.dashboard(userID: context.session.userID, limit: Self.topSecretLimit),
                                 as: DashboardResponse.self, in: context)
        var leases: [LeaseWithName] = []
        if !home.activeLeasesForUser.isEmpty {
            let names = try await leaseNames(for: home.activeLeasesForUser, in: context)
            leases = home.activeLeasesForUser.enumerated().map { index, lease in
                LeaseWithName(lease: lease, secretName: names["l\(index)"] ?? "A secret")
            }
        }
        return DashboardData(stats: home.secretStats, topSecrets: home.topAccessedSecrets, leases: leases)
    }

    func folders(_ context: ServerContext) async throws -> [Folder] {
        try await run(Operations.folders, as: FoldersResponse.self, in: context).folders
    }

    func contents(ofFolder folderID: String, _ context: ServerContext) async throws -> FolderContents {
        let result = try await run(Operations.contents(folderID: folderID), as: ContentsResponse.self, in: context)
        return FolderContents(secrets: result.secretsInFolder, types: result.secretTypes)
    }

    func secret(id: String, _ context: ServerContext) async throws -> SecretDetail {
        let result = try await run(Operations.detail(id: id), as: DetailResponse.self, in: context)
        guard let secret = result.secret else { throw VaultError.notFound }

        var values: [String: String] = [:]
        if secret.isReadable {
            let fields = try await run(Operations.fields(id: id), as: FieldsResponse.self, in: context)
            for field in fields.secretFields {
                if let value = field.value {
                    values[field.key] = value
                }
            }
        }
        let tree = FolderTree(folders: result.folders)
        return SecretDetail(
            summary: secret.summary,
            type: result.secretTypes.first { $0.id == secret.typeId },
            values: values,
            lease: result.activeLease,
            folderPath: secret.folderId.flatMap { tree.path(of: $0) },
            expiresAt: secret.expiresAt.flatMap(GatewayDate.parse),
            verifiedAt: secret.verifiedAt.flatMap(GatewayDate.parse),
            nextRotationAt: secret.nextRotationAt.flatMap(GatewayDate.parse)
        )
    }

    func reveal(secretID: String, fieldKey: String, _ context: ServerContext) async throws -> String {
        try await run(Operations.reveal(id: secretID, fieldKey: fieldKey), as: RevealResponse.self, in: context)
            .revealSecretField
    }

    func checkout(secretID: String, _ context: ServerContext) async throws -> Lease {
        try await run(Operations.checkout(secretID: secretID), as: CheckoutResponse.self, in: context).checkoutSecret
    }

    func checkin(secretID: String, _ context: ServerContext) async throws {
        _ = try await run(Operations.checkin(secretID: secretID), as: CheckinResponse.self, in: context)
    }

    // MARK: Helpers

    private func run<T: Decodable>(
        _ operation: GraphQLOperation,
        as type: T.Type,
        in context: ServerContext
    ) async throws -> T {
        let data = try await transport.execute(operation, in: context)
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw VaultError.unexpected
        }
    }

    private func leaseNames(for leases: [Lease], in context: ServerContext) async throws -> [String: String] {
        let answer = try await run(Operations.leaseNames(for: leases), as: [String: NameNode?].self, in: context)
        return answer.compactMapValues { $0?.name }
    }

    // MARK: Answers

    private struct NameNode: Decodable {
        let id: String
        let name: String
    }

    private struct DashboardResponse: Decodable {
        let secretStats: SecretStats
        let topAccessedSecrets: [SecretSummary]
        let activeLeasesForUser: [Lease]
    }

    private struct FoldersResponse: Decodable {
        let folders: [Folder]
    }

    private struct ContentsResponse: Decodable {
        let secretsInFolder: [SecretSummary]
        let secretTypes: [SecretType]
    }

    private struct DetailSecret: Decodable {
        let id: String
        let name: String
        let canRead: Bool?
        let folderId: String?
        let typeId: String?
        let targetId: String?
        let expiresAt: String?
        let lastHeartbeatResult: String?
        let verifiedAt: String?
        let retired: Bool?
        let viewCount: Int?
        let lastAccessedAt: String?
        let nextRotationAt: String?

        var isReadable: Bool {
            canRead ?? true
        }

        var summary: SecretSummary {
            SecretSummary(
                id: id, name: name, folderId: folderId, typeId: typeId, targetId: targetId,
                lastHeartbeatResult: lastHeartbeatResult, retired: retired, canRead: canRead,
                viewCount: viewCount, lastAccessedAt: lastAccessedAt
            )
        }
    }

    private struct DetailResponse: Decodable {
        let secret: DetailSecret?
        let secretTypes: [SecretType]
        let activeLease: Lease?
        let folders: [Folder]
    }

    private struct FieldsResponse: Decodable {
        let secretFields: [FieldValue]
    }

    private struct RevealResponse: Decodable {
        let revealSecretField: String
    }

    private struct CheckoutResponse: Decodable {
        let checkoutSecret: Lease
    }

    private struct CheckinResponse: Decodable {
        let checkinSecret: Bool
    }
}
