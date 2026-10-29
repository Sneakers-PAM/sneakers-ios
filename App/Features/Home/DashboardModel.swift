// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Observation
import os

/// The Home dashboard: the counts, what is checked out to me and the most accessed secrets.
@MainActor
@Observable
final class DashboardModel {
    enum Phase: Equatable {
        case loading
        case loaded(DashboardData)
        case failed(String)
    }

    private static let logger = Logger(subsystem: "com.therabbithole.app.apple.sneakers-pam", category: "home")

    private(set) var phase = Phase.loading

    var isEmpty: Bool {
        guard case let .loaded(data) = phase else { return false }
        return data.stats.total == 0 && data.leases.isEmpty
    }

    func load(_ access: VaultAccess) async {
        do {
            let data = try await access.perform { try await access.service.dashboard($0) }
            phase = .loaded(data)
            Self.logger.debug("dashboard loaded")
        } catch {
            let failure = error as? VaultError ?? .unexpected
            Self.logger.info("dashboard failed: \(String(describing: failure), privacy: .public)")
            phase = .failed(failure.message)
        }
    }
}
