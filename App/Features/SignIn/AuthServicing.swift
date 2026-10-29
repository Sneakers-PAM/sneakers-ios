// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// Signs a person in to one server. The real one calls the gateway's sign-in routes; tests fake it.
nonisolated protocol AuthServicing: Sendable {
    func login(to server: ServerURL, username: String, password: String) async throws -> LoginOutcome

    func verify(
        on server: ServerURL,
        challenge: SecondFactorChallenge,
        kind: SecondFactorKind,
        code: String
    ) async throws -> AuthenticatedSession

    func sendEmailCode(on server: ServerURL, challenge: SecondFactorChallenge) async throws

    /// Asks the server whether a saved session is still signed in. Nil when it is not.
    func currentSession(on server: ServerURL, stored: AuthenticatedSession) async throws -> AuthenticatedSession?

    /// Ends the session on the server. The app signs out locally even when this fails.
    func logout(on server: ServerURL, session: AuthenticatedSession) async

    /// Starts setting up an authenticator app and returns the secret to scan.
    func startSetup(on server: ServerURL, session: AuthenticatedSession) async throws
        -> AuthenticatorEnrollment

    /// Finishes setup by proving the authenticator app produces the right code.
    func confirmSetup(on server: ServerURL, session: AuthenticatedSession, code: String) async throws

    /// Proves a second factor again, for an action the server wants a fresh proof for, such as revealing a value.
    func stepUp(on server: ServerURL, session: AuthenticatedSession, kind: SecondFactorKind, code: String) async throws

    /// Emails a code for a step-up.
    func sendStepUpEmail(on server: ServerURL, session: AuthenticatedSession) async throws
}

/// Keeps one session per server on this device. It holds a secret, so the real one is the Keychain.
nonisolated protocol SessionStoring: Sendable {
    func load(for serverID: UUID) -> AuthenticatedSession?
    func save(_ session: AuthenticatedSession, for serverID: UUID)
    func delete(for serverID: UUID)
}
