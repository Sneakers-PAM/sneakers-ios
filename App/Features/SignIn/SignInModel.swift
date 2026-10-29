// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Observation
import os

/// The steps of signing in to one server: the password, then a code when the account has a second factor.
/// The password is only ever a parameter, never kept here.
@MainActor
@Observable
final class SignInModel {
    enum Step: Equatable {
        case credentials
        case secondFactor(SecondFactorChallenge, selected: SecondFactorKind)
    }

    private static let logger = Logger(subsystem: "com.therabbithole.app.apple.sneakers-pam", category: "auth")

    private(set) var step = Step.credentials
    private(set) var isWorking = false
    private(set) var message: String?

    let server: ServerEntry
    private let auth: AuthServicing
    private let onSignedIn: (AuthenticatedSession) -> Void
    private var enteredUsername: String?

    init(server: ServerEntry, auth: AuthServicing, onSignedIn: @escaping (AuthenticatedSession) -> Void) {
        self.server = server
        self.auth = auth
        self.onSignedIn = onSignedIn
    }

    /// The factors the person can pick from on the code step. Empty on the password step.
    var availableFactors: [SecondFactorKind] {
        guard case let .secondFactor(challenge, _) = step else { return [] }
        return challenge.factors.filter(SecondFactorKind.supported.contains)
    }

    func submit(username: String, password: String) async {
        let name = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !password.isEmpty else {
            message = "Enter your username and password."
            return
        }
        isWorking = true
        message = nil
        enteredUsername = name
        defer { isWorking = false }

        let outcome: LoginOutcome
        do {
            outcome = try await auth.login(to: server.url, username: name, password: password)
        } catch {
            fail(error)
            return
        }

        switch outcome {
        case let .signedIn(session):
            Self.logger.info("password sign-in complete")
            onSignedIn(named(session))
        case let .secondFactorRequired(challenge):
            await begin(challenge)
        }
    }

    func submitCode(_ code: String) async {
        guard case let .secondFactor(challenge, selected) = step else { return }
        guard code.count == 6, code.allSatisfy({ $0.isASCII && $0.isNumber }) else {
            message = "Enter the 6-digit code."
            return
        }
        isWorking = true
        message = nil
        defer { isWorking = false }

        do {
            let session = try await auth.verify(on: server.url, challenge: challenge, kind: selected, code: code)
            Self.logger.info("second factor accepted")
            onSignedIn(named(session))
        } catch AuthError.attemptExpired {
            Self.logger.info("sign-in attempt expired")
            step = .credentials
            message = AuthError.attemptExpired.message
        } catch {
            fail(error)
        }
    }

    func choose(_ kind: SecondFactorKind) async {
        guard case let .secondFactor(challenge, selected) = step, kind != selected,
              availableFactors.contains(kind) else { return }
        message = nil
        step = .secondFactor(challenge, selected: kind)
        if kind == .email {
            await sendEmailCode(challenge)
        }
    }

    func resendEmailCode() async {
        guard case let .secondFactor(challenge, .email) = step else { return }
        message = nil
        await sendEmailCode(challenge)
    }

    func back() {
        step = .credentials
        message = nil
    }

    private func begin(_ challenge: SecondFactorChallenge) async {
        let usable = challenge.factors.filter(SecondFactorKind.supported.contains)
        guard let first = usable.contains(.totp) ? SecondFactorKind.totp : usable.first else {
            message = "This account signs in with a passkey, which this version can't use yet."
            return
        }
        Self.logger.info("second factor required")
        step = .secondFactor(challenge, selected: first)
        if first == .email {
            await sendEmailCode(challenge)
        }
    }

    private func sendEmailCode(_ challenge: SecondFactorChallenge) async {
        do {
            try await auth.sendEmailCode(on: server.url, challenge: challenge)
            Self.logger.debug("email code requested")
        } catch AuthError.attemptExpired {
            step = .credentials
            message = AuthError.attemptExpired.message
        } catch {
            fail(error)
        }
    }

    private func named(_ session: AuthenticatedSession) -> AuthenticatedSession {
        var named = session
        named.username = enteredUsername
        return named
    }

    private func fail(_ error: Error) {
        let failure = error as? AuthError ?? .unexpected
        Self.logger.info("sign-in step failed: \(String(describing: failure), privacy: .public)")
        message = failure.message
    }
}
