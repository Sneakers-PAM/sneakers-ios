// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

extension SessionManager {
    /// The session manager the running app uses: the real gateway client and the Keychain.
    static func live(arguments: [String] = CommandLine.arguments) -> SessionManager {
        #if DEBUG
            if let manager = uiTesting(arguments: arguments) {
                return manager
            }
        #endif
        return SessionManager(auth: HTTPAuthService(), store: KeychainSessionStore())
    }
}

#if DEBUG
    extension SessionManager {
        /// Launch argument for UI tests that need an already signed-in app. Debug builds only.
        static let signedInArgument = "-uiTestingSignedIn"

        /// Launch argument for UI tests of the wall that appears when the server requires a second factor.
        static let enrolmentRequiredArgument = "-uiTestingEnrolmentRequired"

        private static func uiTesting(arguments: [String]) -> SessionManager? {
            let needsEnrolment = arguments.contains(enrolmentRequiredArgument)
            if arguments.contains(signedInArgument) || needsEnrolment {
                let store = TransientSessionStore()
                var session = AuthenticatedSession(cookieValue: "ui-test", csrfToken: "ui-test", userID: "ui-test")
                session.enrolmentRequired = needsEnrolment
                store.save(session, for: ServerRegistry.uiTestingServerID)
                return SessionManager(auth: OfflineAuthService(), store: store)
            }
            let serverArguments = [ServerRegistry.oneServerArgument, ServerRegistry.emptyServersArgument]
            if serverArguments.contains(where: arguments.contains) {
                return SessionManager(auth: OfflineAuthService(), store: TransientSessionStore())
            }
            return nil
        }
    }

    /// Keeps sessions in memory only. The UI tests use it so they never touch the Keychain.
    private final class TransientSessionStore: SessionStoring, @unchecked Sendable {
        private var sessions: [UUID: AuthenticatedSession] = [:]

        func load(for serverID: UUID) -> AuthenticatedSession? {
            sessions[serverID]
        }

        func save(_ session: AuthenticatedSession, for serverID: UUID) {
            sessions[serverID] = session
        }

        func delete(for serverID: UUID) {
            sessions[serverID] = nil
        }
    }

    /// Never reaches a server. A saved session is taken as still good, and every sign-in attempt fails as unreachable.
    private struct OfflineAuthService: AuthServicing {
        func login(to _: ServerURL, username _: String, password _: String) async throws -> LoginOutcome {
            throw AuthError.unreachable
        }

        func verify(
            on _: ServerURL,
            challenge _: SecondFactorChallenge,
            kind _: SecondFactorKind,
            code _: String
        ) async throws -> AuthenticatedSession {
            throw AuthError.unreachable
        }

        func sendEmailCode(on _: ServerURL, challenge _: SecondFactorChallenge) async throws {
            throw AuthError.unreachable
        }

        func currentSession(on _: ServerURL, stored: AuthenticatedSession) async throws -> AuthenticatedSession? {
            stored
        }

        func logout(on _: ServerURL, session _: AuthenticatedSession) async {}

        func startSetup(on _: ServerURL, session _: AuthenticatedSession) async throws -> AuthenticatorEnrollment {
            throw AuthError.unreachable
        }

        func confirmSetup(on _: ServerURL, session _: AuthenticatedSession, code _: String) async throws {
            throw AuthError.unreachable
        }
    }
#endif
