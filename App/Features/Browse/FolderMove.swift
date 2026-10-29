// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// How the vault gates a move, as the web works it out before asking the right question.
nonisolated enum MoveKind: Equatable, Sendable {
    /// Done at once.
    case direct
    /// Shared content going into a personal folder needs a site admin's approval.
    case request
    /// Out of a personal folder into a shared one: it is shared, so it is confirmed first.
    case share
}

/// A folder a move can go to, with its path to tell it apart.
nonisolated struct MoveDestination: Identifiable, Equatable, Sendable {
    let folder: Folder
    let label: String

    var id: String {
        folder.id
    }
}

nonisolated extension FolderTree {
    /// Every ancestor of a folder from the top down, ending with the folder itself. Empty for an unknown folder.
    func lineage(of folderID: String) -> [Folder] {
        var chain: [Folder] = []
        var visited: Set<String> = []
        var current: String? = folderID
        while let id = current, let folder = folder(id), !visited.contains(id) {
            visited.insert(id)
            chain.append(folder)
            current = folder.parentId?.isEmpty == false ? folder.parentId : nil
        }
        return chain.reversed()
    }

    private func personalOwner(of folderID: String?) -> String? {
        guard let folderID else { return nil }
        return lineage(of: folderID).first(where: \.isPersonal)?.ownerUserId
    }

    func moveKind(from source: String, to destination: String?, isAdmin: Bool = false) -> MoveKind {
        if let destinationOwner = personalOwner(of: destination) {
            return personalOwner(of: source) == destinationOwner || isAdmin ? .direct : .request
        }
        return folder(source)?.isPersonal == true ? .share : .direct
    }

    func destinations(forFolder folderID: String) -> [MoveDestination] {
        let below = Set(descendants(of: folderID) + [folderID])
        let personal = folder(folderID)?.isPersonal == true
        return everyFolder().filter { candidate in
            candidate.canManage != false && !below.contains(candidate.id) && candidate.isPersonal == personal
        }.map { MoveDestination(folder: $0, label: path(of: $0.id) ?? $0.name) }
    }

    func destinations(forSecretIn folderID: String) -> [MoveDestination] {
        everyFolder().filter { $0.canManage != false && $0.id != folderID }
            .map { MoveDestination(folder: $0, label: path(of: $0.id) ?? $0.name) }
    }
}
