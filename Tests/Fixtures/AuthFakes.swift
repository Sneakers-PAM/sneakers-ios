// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Sneakers_PAM

/// An auth service that answers from scripted results and remembers what it was asked. It never records passwords.
final class FakeAuthService: AuthServicing, @unchecked Sendable {
    var loginResult: Result<LoginOutcome, AuthError> = .failure(.unexpected)
    var verifyResult: Result<AuthenticatedSession, AuthError> = .failure(.unexpected)
    var emailResult: Result<Void, AuthError> = .success(())
    var currentResult: Result<AuthenticatedSession?, AuthError> = .success(nil)
    var enrollResult: Result<AuthenticatorEnrollment, AuthError> = .failure(.unexpected)
    var confirmResult: Result<Void, AuthError> = .success(())
    private(set) var enrollStarts = 0
    private(set) var confirmCodes: [String] = []

    private(set) var loginUsernames: [String] = []
    private(set) var verifications: [(kind: SecondFactorKind, code: String)] = []
    private(set) var emailSends = 0
    private(set) var currentChecks = 0
    private(set) var logouts = 0

    func login(to _: ServerURL, username: String, password _: String) async throws -> LoginOutcome {
        loginUsernames.append(username)
        return try loginResult.get()
    }

    func verify(
        on _: ServerURL,
        challenge _: SecondFactorChallenge,
        kind: SecondFactorKind,
        code: String
    ) async throws -> AuthenticatedSession {
        verifications.append((kind, code))
        return try verifyResult.get()
    }

    func sendEmailCode(on _: ServerURL, challenge _: SecondFactorChallenge) async throws {
        emailSends += 1
        try emailResult.get()
    }

    func currentSession(on _: ServerURL, stored _: AuthenticatedSession) async throws -> AuthenticatedSession? {
        currentChecks += 1
        return try currentResult.get()
    }

    func logout(on _: ServerURL, session _: AuthenticatedSession) async {
        logouts += 1
    }

    func startSetup(on _: ServerURL, session _: AuthenticatedSession) async throws -> AuthenticatorEnrollment {
        enrollStarts += 1
        return try enrollResult.get()
    }

    func confirmSetup(on _: ServerURL, session _: AuthenticatedSession, code: String) async throws {
        confirmCodes.append(code)
        try confirmResult.get()
    }
}

/// A session store that keeps sessions in a dictionary.
final class InMemorySessionStore: SessionStoring, @unchecked Sendable {
    private(set) var sessions: [UUID: AuthenticatedSession] = [:]
    private(set) var deletes = 0

    func load(for serverID: UUID) -> AuthenticatedSession? {
        sessions[serverID]
    }

    func save(_ session: AuthenticatedSession, for serverID: UUID) {
        sessions[serverID] = session
    }

    func delete(for serverID: UUID) {
        deletes += 1
        sessions[serverID] = nil
    }
}

extension AuthenticatedSession {
    static func fixture(cookie: String = "cookie-1", csrf: String = "csrf-1", user: String = "u-1") -> Self {
        Self(cookieValue: cookie, csrfToken: csrf, userID: user)
    }
}

extension ServerEntry {
    static func fixture(host: String = "one.example.org") -> ServerEntry {
        // The address is a constant in the tests, so parsing cannot fail.
        // swiftlint:disable:next force_try
        ServerEntry(id: UUID(), url: try! ServerURL(input: host), addedAt: Date(timeIntervalSince1970: 0))
    }
}
