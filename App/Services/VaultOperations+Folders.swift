// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// The folder, move and create operations.
nonisolated extension Operations {
    static func createFolder(parentID: String?, name: String) -> GraphQLOperation {
        var variables: [String: GraphQLValue] = ["name": .string(name)]
        if let parentID {
            variables["parentId"] = .string(parentID)
        }
        return GraphQLOperation(
            name: "BrowseCreateFolder",
            query: """
            mutation BrowseCreateFolder($parentId: String, $name: String!) {
              createFolder(parentId: $parentId, name: $name) { \(folderFields) }
            }
            """,
            variables: variables
        )
    }

    static func renameFolder(id: String, name: String) -> GraphQLOperation {
        GraphQLOperation(
            name: "BrowseRenameFolder",
            query: """
            mutation BrowseRenameFolder($id: ID!, $name: String!) { renameFolder(id: $id, name: $name) { id } }
            """,
            variables: ["id": .string(id), "name": .string(name)]
        )
    }

    static func moveFolder(id: String, to parentID: String?) -> GraphQLOperation {
        var variables: [String: GraphQLValue] = ["id": .string(id)]
        if let parentID {
            variables["newParentId"] = .string(parentID)
        }
        return GraphQLOperation(
            name: "BrowseMoveFolder",
            query: """
            mutation BrowseMoveFolder($id: ID!, $newParentId: String) {
              moveFolder(id: $id, newParentId: $newParentId) { id }
            }
            """,
            variables: variables
        )
    }

    static func moveSecret(id: String, to folderID: String) -> GraphQLOperation {
        GraphQLOperation(
            name: "BrowseMoveSecret",
            query: """
            mutation BrowseMoveSecret($id: ID!, $input: UpdateSecretInput!) {
              updateSecret(id: $id, input: $input) { id }
            }
            """,
            variables: ["id": .string(id), "input": .object(["folderId": .string(folderID)])]
        )
    }

    static func requestMove(_ request: MoveRequest) -> GraphQLOperation {
        var variables: [String: GraphQLValue] = [:]
        let reason = request.reason.trimmingCharacters(in: .whitespacesAndNewlines)
        if !reason.isEmpty {
            variables["reason"] = .string(reason)
        }
        switch request.subject {
        case let .secret(id, name):
            variables["secretId"] = .string(id)
            variables["destFolderId"] = .string(request.destinationID)
            variables["secretName"] = .string(name)
            variables["destFolderName"] = .string(request.destinationName)
            return GraphQLOperation(
                name: "BrowseCreateSecretMoveRequest",
                query: """
                mutation BrowseCreateSecretMoveRequest(
                  $secretId: String!, $destFolderId: String!, $reason: String, $secretName: String,
                  $destFolderName: String
                ) {
                  createSecretMoveRequest(
                    secretId: $secretId, destFolderId: $destFolderId, reason: $reason, secretName: $secretName,
                    destFolderName: $destFolderName
                  ) { id }
                }
                """,
                variables: variables
            )
        case let .folder(id, name):
            variables["folderId"] = .string(id)
            variables["destParentId"] = .string(request.destinationID)
            variables["folderName"] = .string(name)
            variables["destParentName"] = .string(request.destinationName)
            return GraphQLOperation(
                name: "BrowseCreateFolderMoveRequest",
                query: """
                mutation BrowseCreateFolderMoveRequest(
                  $folderId: String!, $destParentId: String!, $reason: String, $folderName: String,
                  $destParentName: String
                ) {
                  createFolderMoveRequest(
                    folderId: $folderId, destParentId: $destParentId, reason: $reason, folderName: $folderName,
                    destParentName: $destParentName
                  ) { id }
                }
                """,
                variables: variables
            )
        }
    }

    static var secretTypes: GraphQLOperation {
        GraphQLOperation(
            name: "CreateSecretTypes",
            query: "query CreateSecretTypes { secretTypes { \(typeFields) } }"
        )
    }

    static func createSecret(_ secret: NewSecret) -> GraphQLOperation {
        let pairs = secret.fields.sorted { $0.key < $1.key }.map { pair in
            GraphQLValue.object(["key": .string(pair.key), "value": .string(pair.value)])
        }
        var input: [String: GraphQLValue] = ["name": .string(secret.name), "folderId": .string(secret.folderID)]
        input["typeId"] = .string(secret.typeID)
        input["fields"] = .list(pairs)
        return GraphQLOperation(
            name: "EditorsCreateSecret",
            query: """
            mutation EditorsCreateSecret($input: CreateSecretInput!) {
              createSecret(input: $input) { id }
            }
            """,
            variables: ["input": .object(input)]
        )
    }

    static func exportCertificate(_ request: CertificateExportRequest) -> GraphQLOperation {
        var variables: [String: GraphQLValue] = ["secretId": .string(request.secretID)]
        variables["format"] = .string(request.format)
        if let passphrase = request.passphrase {
            variables["newPassphrase"] = .string(passphrase)
        }
        return GraphQLOperation(
            name: "SecretExportCertificate",
            query: """
            mutation SecretExportCertificate($secretId: String!, $format: String!, $newPassphrase: String) {
              exportCertificate(secretId: $secretId, format: $format, newPassphrase: $newPassphrase) {
                fileBase64 filename contentType
              }
            }
            """,
            variables: variables
        )
    }
}
