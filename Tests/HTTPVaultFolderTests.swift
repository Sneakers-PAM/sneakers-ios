// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Sneakers_PAM
import Testing

struct HTTPVaultFolderTests {
    private let transport = FakeGraphQLTransport()
    private var service: HTTPVaultService {
        HTTPVaultService(transport: transport)
    }

    @Test func foldersCarryTheirScopeOwnerAndWhetherIMayManageThem() async throws {
        transport.answer("BrowseFolders", """
        {"folders":[{"id":"4","name":"Mine","parentId":null,"scope":"personal","ownerUserId":"me",
          "canManage":true,"subtreeSecretCount":2}]}
        """)

        let folders = try await service.folders(.fixture)

        #expect(folders.first?.isPersonal == true)
        #expect(folders.first?.ownerUserId == "me")
        #expect(folders.first?.canManage == true)
    }

    @Test func aNewFolderIsCreatedUnderItsParent() async throws {
        transport.answer("BrowseCreateFolder", #"{"createFolder":{"id":"9","name":"Lab","parentId":"1"}}"#)

        let folder = try await service.createFolder(parentID: "1", name: "Lab", .fixture)

        #expect(folder.id == "9")
        let variables = transport.operation(named: "BrowseCreateFolder")?.variables
        #expect(variables?["parentId"] == .string("1"))
        #expect(variables?["name"] == .string("Lab"))
    }

    @Test func aTopLevelFolderSendsNoParent() async throws {
        transport.answer("BrowseCreateFolder", #"{"createFolder":{"id":"9","name":"Lab","parentId":null}}"#)

        _ = try await service.createFolder(parentID: nil, name: "Lab", .fixture)

        #expect(transport.operation(named: "BrowseCreateFolder")?.variables["parentId"] == nil)
    }

    @Test func renamingAFolderSendsItsIdAndTheNewName() async throws {
        transport.answer("BrowseRenameFolder", #"{"renameFolder":{"id":"1","name":"Core"}}"#)

        try await service.renameFolder(id: "1", name: "Core", .fixture)

        let variables = transport.operation(named: "BrowseRenameFolder")?.variables
        #expect(variables?["id"] == .string("1"))
        #expect(variables?["name"] == .string("Core"))
    }

    @Test func movingAFolderSendsItsNewParent() async throws {
        transport.answer("BrowseMoveFolder", #"{"moveFolder":{"id":"2","parentId":"3"}}"#)

        try await service.moveFolder(id: "2", to: "3", .fixture)

        let variables = transport.operation(named: "BrowseMoveFolder")?.variables
        #expect(variables?["id"] == .string("2"))
        #expect(variables?["newParentId"] == .string("3"))
    }

    @Test func movingASecretSendsItsNewFolder() async throws {
        transport.answer("BrowseMoveSecret", #"{"updateSecret":{"id":"s1"}}"#)

        try await service.moveSecret(id: "s1", to: "3", .fixture)

        let variables = transport.operation(named: "BrowseMoveSecret")?.variables
        #expect(variables?["id"] == .string("s1"))
        guard case let .object(input)? = variables?["input"] else {
            Issue.record("the input is missing")
            return
        }
        #expect(input["folderId"] == .string("3"))
    }

    @Test func aMoveThatNeedsApprovalIsAskedForWithItsReasonAndNames() async throws {
        transport.answer("BrowseCreateSecretMoveRequest", #"{"createSecretMoveRequest":{"id":"r1"}}"#)
        let request = MoveRequest(
            subject: .secret(id: "s1", name: "DB admin"), destinationID: "6", destinationName: "Theirs",
            reason: "It is mine now"
        )

        try await service.requestMove(request, .fixture)

        let variables = transport.operation(named: "BrowseCreateSecretMoveRequest")?.variables
        #expect(variables?["secretId"] == .string("s1"))
        #expect(variables?["destFolderId"] == .string("6"))
        #expect(variables?["reason"] == .string("It is mine now"))
        #expect(variables?["secretName"] == .string("DB admin"))
        #expect(variables?["destFolderName"] == .string("Theirs"))
    }

    @Test func aFolderMoveThatNeedsApprovalUsesTheFolderRequest() async throws {
        transport.answer("BrowseCreateFolderMoveRequest", #"{"createFolderMoveRequest":{"id":"r2"}}"#)
        let request = MoveRequest(
            subject: .folder(id: "2", name: "Databases"), destinationID: "6", destinationName: "Theirs", reason: ""
        )

        try await service.requestMove(request, .fixture)

        let variables = transport.operation(named: "BrowseCreateFolderMoveRequest")?.variables
        #expect(variables?["folderId"] == .string("2"))
        #expect(variables?["destParentId"] == .string("6"))
        #expect(variables?["reason"] == nil)
    }

    @Test func theTypesASecretCanBeCreatedWithAreListed() async throws {
        transport.answer("CreateSecretTypes", """
        {"secretTypes":[{"id":"t1","name":"Database account","checkout":true,"heartbeat":true,"rotation":false,
          "fields":[{"key":"username","label":"Username","kind":"text","required":true}]}]}
        """)

        let types = try await service.secretTypes(.fixture)

        #expect(types.map(\.name) == ["Database account"])
        #expect(types.first?.fields?.first?.isRequired == true)
    }

    @Test func aNewSecretSendsItsNameFolderTypeAndFields() async throws {
        transport.answer("EditorsCreateSecret", #"{"createSecret":{"id":"s9"}}"#)
        let secret = NewSecret(name: "Vendor", folderID: "3", typeID: "t1", fields: ["username": "bob"])

        let id = try await service.createSecret(secret, .fixture)

        #expect(id == "s9")
        guard case let .object(input)? = transport.operation(named: "EditorsCreateSecret")?.variables["input"] else {
            Issue.record("the input is missing")
            return
        }
        #expect(input["name"] == .string("Vendor"))
        #expect(input["folderId"] == .string("3"))
        #expect(input["typeId"] == .string("t1"))
        guard case let .list(fields)? = input["fields"] else {
            Issue.record("the fields are missing")
            return
        }
        #expect(fields.count == 1)
    }
}
