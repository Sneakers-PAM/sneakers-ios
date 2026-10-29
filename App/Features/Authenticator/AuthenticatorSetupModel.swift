// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Observation
import os

/// Setting up an authenticator app: ask the server for a secret, show it to scan, then prove the app makes the
/// right code. The secret is only held while this screen is open and is never logged.
@MainActor
@Observable
final class AuthenticatorSetupModel {
    enum Step: Equatable {
        case preparing
        case scan(AuthenticatorEnrollment)
        case failed
    }

    private static let logger = Logger(subsystem: "com.therabbithole.app.apple.sneakers-pam", category: "auth")

    private(set) var step = Step.preparing
    private(set) var isWorking = false
    private(set) var message: String?
    /// True once the server has accepted the code and the app has taken the new session state.
    private(set) var isEnrolled = false

    private let server: ServerEntry
    private let session: AuthenticatedSession
    private let auth: AuthServicing
    private let onEnrolled: () async -> Void

    init(
        server: ServerEntry,
        session: AuthenticatedSession,
        auth: AuthServicing,
        onEnrolled: @escaping () async -> Void
    ) {
        self.server = server
        self.session = session
        self.auth = auth
        self.onEnrolled = onEnrolled
    }

    func start() async {
        isWorking = true
        message = nil
        defer { isWorking = false }
        do {
            let enrollment = try await auth.startSetup(on: server.url, session: session)
            step = .scan(enrollment)
            Self.logger.info("authenticator setup started")
        } catch {
            let failure = error as? AuthError ?? .unexpected
            Self.logger.info("authenticator setup could not start: \(String(describing: failure), privacy: .public)")
            step = .failed
            message = failure.message
        }
    }

    func confirm(code: String) async {
        guard case .scan = step else { return }
        guard code.count == 6, code.allSatisfy({ $0.isASCII && $0.isNumber }) else {
            message = "Enter the 6-digit code."
            return
        }
        isWorking = true
        message = nil
        defer { isWorking = false }
        do {
            try await auth.confirmSetup(on: server.url, session: session, code: code)
            Self.logger.info("authenticator setup confirmed")
            await onEnrolled()
            isEnrolled = true
        } catch {
            let failure = error as? AuthError ?? .unexpected
            Self.logger.info("authenticator setup not confirmed: \(String(describing: failure), privacy: .public)")
            message = failure.message
        }
    }
}
