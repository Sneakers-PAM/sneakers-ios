// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Sneakers_PAM
import Testing

@MainActor
struct FolderEditModelsTests {
    private let vault = FakeVaultService()

    private func makeAccess() -> VaultAccess {
        VaultAccess(service: vault, context: { .fixture }, onSessionEnded: {})
    }

    // MARK: Folder names

    @Test func aNewFolderNeedsAName() {
        let model = FolderNameModel(mode: .create(parentID: "1"))

        #expect(!model.canSave)
        model.name = "  Lab "
        #expect(model.canSave)
    }

    @Test func aRenameNeedsAChangedName() {
        let model = FolderNameModel(mode: .rename(id: "1", currentName: "Platform"))

        #expect(!model.canSave)
        model.name = "Platform"
        #expect(!model.canSave)
        model.name = "Core"
        #expect(model.canSave)
    }

    @Test func savingANewFolderCreatesItUnderItsParentWithATrimmedName() async {
        let model = FolderNameModel(mode: .create(parentID: "1"))
        model.name = "  Lab "

        await model.save(makeAccess())

        #expect(vault.createdFolders.first?.parentID == "1")
        #expect(vault.createdFolders.first?.name == "Lab")
        #expect(model.didSave)
    }

    @Test func savingARenameAsksTheServer() async {
        let model = FolderNameModel(mode: .rename(id: "1", currentName: "Platform"))
        model.name = "Core"

        await model.save(makeAccess())

        #expect(vault.renamedFolders.first?.id == "1")
        #expect(vault.renamedFolders.first?.name == "Core")
        #expect(model.didSave)
    }

    @Test func aRefusedFolderSaveSaysWhy() async {
        vault.folderActionResult = .failure(.noAccess)
        vault.folderResult = .failure(.noAccess)
        let model = FolderNameModel(mode: .create(parentID: nil))
        model.name = "Lab"

        await model.save(makeAccess())

        #expect(!model.didSave)
        #expect(model.message == VaultError.noAccess.message)
    }

    // MARK: New secret

    private var databaseType: SecretType {
        let username = FieldDefinition(
            key: "username", label: "Username", kind: "text", sensitive: false, superSensitive: false, required: true
        )
        let password = FieldDefinition(
            key: "password", label: "Password", kind: "password", sensitive: true, superSensitive: false, required: true
        )
        return SecretType(id: "t1", name: "Database account", checkout: true, fields: [username, password])
    }

    @Test func aNewSecretStartsOnTheFirstTypeWithEmptyFields() {
        let model = CreateSecretModel(folderID: "3", types: [databaseType])

        #expect(model.type?.id == "t1")
        #expect(model.value(for: "username") == "")
        #expect(!model.canSave)
    }

    @Test func aNewSecretNeedsANameAndEveryRequiredField() {
        let model = CreateSecretModel(folderID: "3", types: [databaseType])
        model.name = "Vendor"
        model.set("bob", for: "username")
        #expect(!model.canSave)

        model.set("hunter2", for: "password")
        #expect(model.canSave)
    }

    @Test func changingTheTypeStartsTheFieldsAgain() {
        let other = SecretType(
            id: "t2", name: "Note", checkout: false,
            fields: [FieldDefinition(
                key: "body",
                label: "Body",
                kind: "multiline",
                sensitive: false,
                superSensitive: false
            )]
        )
        let model = CreateSecretModel(folderID: "3", types: [databaseType, other])
        model.set("bob", for: "username")

        model.selectType("t2")

        #expect(model.type?.id == "t2")
        #expect(model.value(for: "username") == "")
        #expect(model.editableFields.map(\.key) == ["body"])
    }

    @Test func savingANewSecretSendsItsNameFolderTypeAndFields() async {
        let model = CreateSecretModel(folderID: "3", types: [databaseType])
        model.name = " Vendor "
        model.set("bob", for: "username")
        model.set("hunter2", for: "password")

        await model.save(makeAccess())

        let sent = vault.createdSecrets.first
        #expect(sent?.name == "Vendor")
        #expect(sent?.folderID == "3")
        #expect(sent?.typeID == "t1")
        #expect(sent?.fields == ["username": "bob", "password": "hunter2"])
        #expect(model.createdID == "s-new")
    }

    @Test func theTypedSecretIsForgottenOnceTheSecretIsCreated() async {
        let model = CreateSecretModel(folderID: "3", types: [databaseType])
        model.name = "Vendor"
        model.set("bob", for: "username")
        model.set("hunter2", for: "password")

        await model.save(makeAccess())

        #expect(model.value(for: "password") == "")
    }

    @Test func theTypesLoadForTheScreen() async {
        vault.typesResult = .success([databaseType])
        let types = await CreateSecretModel.loadTypes(makeAccess())

        #expect(types?.map(\.id) == ["t1"])
    }

    // MARK: Move

    private var tree: FolderTree {
        var folders: [Folder] = []
        folders.append(Folder(id: "1", name: "Platform", parentId: nil, subtreeSecretCount: nil, scope: "group"))
        folders.append(Folder(id: "3", name: "Apps", parentId: nil, subtreeSecretCount: nil, scope: "group"))
        folders.append(Folder(
            id: "6", name: "Theirs", parentId: nil, subtreeSecretCount: nil, scope: "personal", ownerUserId: "other"
        ))
        return FolderTree(folders: folders)
    }

    @Test func aMoveStartsWithNothingChosen() {
        let model = MoveModel(subject: .secret(id: "s1", name: "DB admin", folderID: "1"), tree: tree)

        #expect(model.destinations.map(\.label).contains("Apps"))
        #expect(!model.destinations.map(\.label).contains("Platform"))
        #expect(!model.canMove)
    }

    @Test func movingSharedToSharedIsDirectAndMovesTheSecret() async {
        let model = MoveModel(subject: .secret(id: "s1", name: "DB admin", folderID: "1"), tree: tree)
        model.destinationID = "3"

        #expect(model.kind == .direct)
        await model.perform(makeAccess())

        #expect(vault.movedSecrets.first?.id == "s1")
        #expect(vault.movedSecrets.first?.folderID == "3")
        #expect(model.outcome == .moved)
    }

    @Test func movingAFolderMovesItUnderTheDestination() async {
        let model = MoveModel(subject: .folder(id: "1", name: "Platform", parentID: nil), tree: tree)
        model.destinationID = "3"

        await model.perform(makeAccess())

        #expect(vault.movedFolders.first?.id == "1")
        #expect(vault.movedFolders.first?.parentID == "3")
        #expect(model.outcome == .moved)
    }

    @Test func intoSomeoneElsesPersonalFolderItBecomesARequestThatNeedsAReason() async {
        let model = MoveModel(subject: .secret(id: "s1", name: "DB admin", folderID: "1"), tree: tree)
        model.destinationID = "6"

        #expect(model.kind == .request)
        #expect(!model.canMove)
        model.reason = "It is mine now"
        #expect(model.canMove)

        await model.perform(makeAccess())

        #expect(vault.movedSecrets.isEmpty)
        #expect(vault.moveRequests.first?.destinationID == "6")
        #expect(vault.moveRequests.first?.reason == "It is mine now")
        #expect(model.outcome == .requested)
    }

    @Test func aRefusedMoveSaysWhyAndDoesNotReportDone() async {
        vault.folderActionResult = .failure(.noAccess)
        let model = MoveModel(subject: .secret(id: "s1", name: "DB admin", folderID: "1"), tree: tree)
        model.destinationID = "3"

        await model.perform(makeAccess())

        #expect(model.outcome == nil)
        #expect(model.message == VaultError.noAccess.message)
    }
}
