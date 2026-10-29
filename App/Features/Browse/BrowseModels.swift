// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Observation
import os

/// The folder tree.
@MainActor
@Observable
final class FoldersModel {
    private static let logger = Logger(subsystem: "com.therabbithole.app.apple.sneakers-pam", category: "browse")

    private(set) var tree = FolderTree(folders: [])
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var message: String?

    func load(_ access: VaultAccess) async {
        isLoading = true
        message = nil
        defer { isLoading = false }
        do {
            let folders = try await access.perform { try await access.service.folders($0) }
            tree = FolderTree(folders: folders)
            hasLoaded = true
            Self.logger.debug("folders loaded")
        } catch {
            let failure = error as? VaultError ?? .unexpected
            Self.logger.info("folders failed: \(String(describing: failure), privacy: .public)")
            message = failure.message
        }
    }
}

/// The secrets in one folder, with a name filter. The gateway has no search, so the filter runs on the loaded list.
@MainActor
@Observable
final class SecretListModel {
    private static let logger = Logger(subsystem: "com.therabbithole.app.apple.sneakers-pam", category: "browse")

    let folderID: String
    var search = ""
    private(set) var secrets: [SecretSummary] = []
    private(set) var types: [SecretType] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var message: String?

    init(folderID: String) {
        self.folderID = folderID
    }

    var visibleSecrets: [SecretSummary] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return secrets }
        return secrets.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    /// The field a quick copy takes: the first sensitive one of the secret's type. Nil for a locked secret.
    func primaryFieldKey(for secret: SecretSummary) -> String? {
        guard secret.isReadable else { return nil }
        return types.first { $0.id == secret.typeId }?.primarySensitiveFieldKey
    }

    func load(_ access: VaultAccess) async {
        isLoading = true
        message = nil
        defer { isLoading = false }
        do {
            let contents = try await access.perform { try await access.service.contents(ofFolder: self.folderID, $0) }
            secrets = contents.secrets
            types = contents.types
            hasLoaded = true
            Self.logger.debug("folder contents loaded")
        } catch {
            let failure = error as? VaultError ?? .unexpected
            Self.logger.info("folder contents failed: \(String(describing: failure), privacy: .public)")
            secrets = []
            message = failure.message
        }
    }
}
