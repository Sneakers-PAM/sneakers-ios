// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Sneakers_PAM
import Testing

struct FolderMoveTests {
    private func folder(
        _ id: String, _ name: String, parent: String? = nil, scope: String = "group", owner: String? = nil,
        canManage: Bool? = true
    ) -> Folder {
        Folder(
            id: id, name: name, parentId: parent, subtreeSecretCount: nil,
            scope: scope, ownerUserId: owner, canManage: canManage
        )
    }

    /// Shared: Platform > Databases, Apps. Personal: Mine (owner me) > Lab, Theirs (owner other).
    private var tree: FolderTree {
        var folders: [Folder] = []
        folders.append(folder("1", "Platform"))
        folders.append(folder("2", "Databases", parent: "1"))
        folders.append(folder("3", "Apps"))
        folders.append(folder("4", "Mine", scope: "personal", owner: "me"))
        folders.append(folder("5", "Lab", parent: "4"))
        folders.append(folder("6", "Theirs", scope: "personal", owner: "other"))
        folders.append(folder("7", "Locked", canManage: false))
        return FolderTree(folders: folders)
    }

    @Test func aFolderKnowsItsAncestorsFromTheTopDown() {
        #expect(tree.lineage(of: "2").map(\.name) == ["Platform", "Databases"])
        #expect(tree.lineage(of: "9").isEmpty)
    }

    @Test func movingBetweenSharedFoldersIsDirect() {
        #expect(tree.moveKind(from: "2", to: "3") == .direct)
        #expect(tree.moveKind(from: "2", to: nil) == .direct)
    }

    @Test func movingInsideMyOwnPersonalFolderIsDirect() {
        #expect(tree.moveKind(from: "4", to: "5") == .direct)
    }

    @Test func movingSharedContentIntoSomeoneElsesPersonalFolderNeedsARequest() {
        #expect(tree.moveKind(from: "2", to: "6") == .request)
    }

    @Test func movingSharedContentIntoMyOwnPersonalFolderNeedsARequestToo() {
        #expect(tree.moveKind(from: "2", to: "4") == .request)
    }

    @Test func aSiteAdminMovesStraightIntoAPersonalFolder() {
        #expect(tree.moveKind(from: "2", to: "6", isAdmin: true) == .direct)
    }

    @Test func movingOutOfAPersonalFolderIntoASharedOneSharesIt() {
        #expect(tree.moveKind(from: "4", to: "3") == .share)
    }

    @Test func aFoldersDestinationsExcludeItselfItsDescendantsAndFoldersIMayNotManage() {
        let names = tree.destinations(forFolder: "1").map(\.label)

        #expect(!names.contains("Platform"))
        #expect(!names.contains("Platform / Databases"))
        #expect(!names.contains("Locked"))
        #expect(names.contains("Apps"))
    }

    @Test func aFolderOnlyMovesAmongFoldersOfTheSameKind() {
        let names = tree.destinations(forFolder: "3").map(\.label)

        #expect(!names.contains("Mine"))
        #expect(!names.contains("Theirs"))
        #expect(names.contains("Platform"))
    }

    @Test func aSecretCanGoToAnyFolderIMayManageExceptItsOwn() {
        let names = tree.destinations(forSecretIn: "2").map(\.label)

        #expect(!names.contains("Platform / Databases"))
        #expect(names.contains("Apps"))
        #expect(!names.contains("Locked"))
    }

    @Test func destinationsAreLabelledWithTheirPath() {
        #expect(tree.destinations(forSecretIn: "3").map(\.label).contains("Platform / Databases"))
    }
}
