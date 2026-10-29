// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Observation

/// How the vault screens reach the server: the service, and the active server and signed-in session at the moment of
/// each call. When the server says the session is over, it tells the app so the sign-in screen can come back.
@MainActor @Observable
final class VaultAccess {
    let service: VaultServicing
    private let currentContext: () -> ServerContext?
    private let onSessionEnded: () -> Void

    init(service: VaultServicing, context: @escaping () -> ServerContext?, onSessionEnded: @escaping () -> Void) {
        self.service = service
        currentContext = context
        self.onSessionEnded = onSessionEnded
    }

    func context() throws -> ServerContext {
        guard let context = currentContext() else { throw VaultError.sessionEnded }
        return context
    }

    func perform<T>(_ work: (ServerContext) async throws -> T) async throws -> T {
        let context = try context()
        do {
            return try await work(context)
        } catch VaultError.sessionEnded {
            onSessionEnded()
            throw VaultError.sessionEnded
        }
    }

    func reportSessionEnded() {
        onSessionEnded()
    }
}
