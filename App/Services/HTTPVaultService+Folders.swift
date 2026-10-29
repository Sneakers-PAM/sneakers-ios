// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// Creating, renaming and moving folders and secrets.
extension HTTPVaultService {
    func createFolder(parentID: String?, name: String, _ context: ServerContext) async throws -> Folder {
        try await run(
            Operations.createFolder(parentID: parentID, name: name),
            as: CreateFolderResponse.self,
            in: context
        )
        .createFolder
    }

    func renameFolder(id: String, name: String, _ context: ServerContext) async throws {
        _ = try await run(Operations.renameFolder(id: id, name: name), as: RenameFolderResponse.self, in: context)
    }

    func moveFolder(id: String, to parentID: String?, _ context: ServerContext) async throws {
        _ = try await run(Operations.moveFolder(id: id, to: parentID), as: MoveFolderResponse.self, in: context)
    }

    func moveSecret(id: String, to folderID: String, _ context: ServerContext) async throws {
        _ = try await run(Operations.moveSecret(id: id, to: folderID), as: UpdateResponse.self, in: context)
    }

    func requestMove(_ request: MoveRequest, _ context: ServerContext) async throws {
        _ = try await run(Operations.requestMove(request), as: MoveRequestResponse.self, in: context)
    }

    func secretTypes(_ context: ServerContext) async throws -> [SecretType] {
        try await run(Operations.secretTypes, as: TypesResponse.self, in: context).secretTypes
    }

    func createSecret(_ secret: NewSecret, _ context: ServerContext) async throws -> String {
        try await run(Operations.createSecret(secret), as: CreateSecretResponse.self, in: context).createSecret.id
    }

    struct CreateFolderResponse: Decodable {
        let createFolder: Folder
    }

    struct RenameFolderResponse: Decodable {
        let renameFolder: UpdatedSecret
    }

    struct MoveFolderResponse: Decodable {
        let moveFolder: UpdatedSecret
    }

    /// Either request mutation answers with the request's id, under its own name.
    struct MoveRequestResponse: Decodable {
        let createSecretMoveRequest: UpdatedSecret?
        let createFolderMoveRequest: UpdatedSecret?
    }

    struct TypesResponse: Decodable {
        let secretTypes: [SecretType]
    }

    struct CreateSecretResponse: Decodable {
        let createSecret: UpdatedSecret
    }
}
