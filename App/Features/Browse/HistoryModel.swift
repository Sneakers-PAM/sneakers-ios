// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Observation
import os

/// The saved versions of one secret, newest first. Values are never part of it: an old value is read through the
/// reveal coordinator, which asks the server and audits it.
@MainActor
@Observable
final class HistoryModel {
    enum Phase: Equatable {
        case loading
        case loaded([SecretVersion])
        case failed(String)
    }

    private static let logger = Logger(subsystem: "com.therabbithole.app.apple.sneakers-pam", category: "history")

    let secretID: String
    private(set) var phase = Phase.loading

    init(secretID: String) {
        self.secretID = secretID
    }

    /// The version in use cannot be restored over itself.
    func canRestore(_ version: SecretVersion) -> Bool {
        !version.active
    }

    func load(_ access: VaultAccess) async {
        do {
            let versions = try await access.perform { try await access.service.versions(secretID: self.secretID, $0) }
            phase = .loaded(versions.sortedNewestFirst())
        } catch {
            let failure = error as? VaultError ?? .unexpected
            Self.logger.info("history failed: \(String(describing: failure), privacy: .public)")
            phase = .failed(failure.message)
        }
    }
}
