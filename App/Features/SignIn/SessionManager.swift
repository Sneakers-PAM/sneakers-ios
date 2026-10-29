// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Observation
import os

nonisolated enum RestoreResult: Equatable, Sendable {
    case signedIn
    case signedOut
    case unreachable
}

/// Which servers are signed in. A saved session counts only once the server has confirmed it, so the app shows
/// nothing but the sign-in screen until then.
@MainActor
@Observable
final class SessionManager {
    private static let logger = Logger(subsystem: "com.therabbithole.app.apple.sneakers-pam", category: "auth")

    /// Counts sign-ins the person just did by hand, so the lock knows not to ask for Face ID right after a password.
    private(set) var interactiveSignIns = 0

    private var sessions: [UUID: AuthenticatedSession] = [:]
    @ObservationIgnored private var signInModels: [UUID: SignInModel] = [:]
    @ObservationIgnored private var setupModels: [UUID: AuthenticatorSetupModel] = [:]
    private let auth: AuthServicing
    private let store: SessionStoring

    init(auth: AuthServicing, store: SessionStoring) {
        self.auth = auth
        self.store = store
    }

    func session(for serverID: UUID) -> AuthenticatedSession? {
        sessions[serverID]
    }

    func isSignedIn(_ serverID: UUID) -> Bool {
        sessions[serverID] != nil
    }

    /// The sign-in steps for a server. The same model is handed back until the person signs in or out, so a redraw
    /// does not lose what they typed.
    func makeSignInModel(for server: ServerEntry) -> SignInModel {
        if let existing = signInModels[server.id] {
            return existing
        }
        let model = SignInModel(server: server, auth: auth) { [weak self] session in
            self?.signedIn(session, for: server)
        }
        signInModels[server.id] = model
        return model
    }

    /// The authenticator setup steps for a signed-in server, or nil when there is no session to set it up with.
    func makeAuthenticatorSetupModel(for server: ServerEntry) -> AuthenticatorSetupModel? {
        guard let session = sessions[server.id] else { return nil }
        if let existing = setupModels[server.id] {
            return existing
        }
        let model = AuthenticatorSetupModel(server: server, session: session, auth: auth) { [weak self] in
            await self?.finishedSetup(for: server)
        }
        setupModels[server.id] = model
        return model
    }

    private func finishedSetup(for server: ServerEntry) async {
        setupModels[server.id] = nil
        await refresh(server)
    }

    func signedIn(_ session: AuthenticatedSession, for server: ServerEntry) {
        signInModels[server.id] = nil
        sessions[server.id] = session
        interactiveSignIns += 1
        store.save(session, for: server.id)
        Self.logger.info("signed in to server \(server.id.uuidString, privacy: .public)")
    }

    /// Looks for a saved session and asks the server whether it is still good.
    func restore(_ server: ServerEntry) async -> RestoreResult {
        guard let stored = store.load(for: server.id) else { return .signedOut }
        do {
            guard let current = try await auth.currentSession(on: server.url, stored: stored) else {
                store.delete(for: server.id)
                Self.logger.info("saved session for server \(server.id.uuidString, privacy: .public) was refused")
                return .signedOut
            }
            sessions[server.id] = current
            store.save(current, for: server.id)
            Self.logger.info("restored session for server \(server.id.uuidString, privacy: .public)")
            return .signedIn
        } catch {
            Self.logger.info("could not confirm the saved session for server \(server.id.uuidString, privacy: .public)")
            return .unreachable
        }
    }

    /// Asks the server for the session's current state, for example after the person finished setting up a second
    /// factor.
    func refresh(_ server: ServerEntry) async {
        guard let stored = sessions[server.id] else { return }
        do {
            if let current = try await auth.currentSession(on: server.url, stored: stored) {
                sessions[server.id] = current
                store.save(current, for: server.id)
            } else {
                sessions[server.id] = nil
                store.delete(for: server.id)
                Self.logger.info("the server ended the session for \(server.id.uuidString, privacy: .public)")
            }
        } catch {
            Self.logger.info("could not refresh the session for \(server.id.uuidString, privacy: .public)")
        }
    }

    func signOut(_ server: ServerEntry) async {
        guard let session = sessions[server.id] else { return }
        await auth.logout(on: server.url, session: session)
        sessions[server.id] = nil
        signInModels[server.id] = nil
        setupModels[server.id] = nil
        store.delete(for: server.id)
        Self.logger.info("signed out of server \(server.id.uuidString, privacy: .public)")
    }

    /// Drops a server's saved session, for when the server is removed from the app.
    func forget(_ serverID: UUID) {
        sessions[serverID] = nil
        signInModels[serverID] = nil
        setupModels[serverID] = nil
        store.delete(for: serverID)
    }
}
