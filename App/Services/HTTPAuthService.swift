// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import os

/// Signs in through the gateway's own JSON routes, the same ones the web app uses. The session cookie is read from
/// the answer and sent by hand, with no shared cookie jar, so every server's session stays separate.
nonisolated struct HTTPAuthService: AuthServicing {
    private static let logger = Logger(subsystem: "com.therabbithole.app.apple.sneakers-pam", category: "auth")
    static let cookieName = "sneakers_sid"
    private static let timeout: TimeInterval = 15

    var session: URLSession = HTTPAuthService.makeSession()

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.timeoutIntervalForRequest = timeout
        return URLSession(configuration: configuration)
    }

    // MARK: AuthServicing

    func login(to server: ServerURL, username: String, password: String) async throws -> LoginOutcome {
        let (data, response) = try await send(Self.loginRequest(to: server, username: username, password: password))
        return try Self.parseLogin(response, data: data)
    }

    func verify(
        on server: ServerURL,
        challenge: SecondFactorChallenge,
        kind: SecondFactorKind,
        code: String
    ) async throws -> AuthenticatedSession {
        let (data, response) = try await send(Self.verifyRequest(
            on: server,
            challenge: challenge,
            kind: kind,
            code: code
        ))
        return try Self.parseVerify(response, data: data)
    }

    func sendEmailCode(on server: ServerURL, challenge: SecondFactorChallenge) async throws {
        let (data, response) = try await send(Self.emailCodeRequest(on: server, challenge: challenge))
        try Self.parseEmailCode(response, data: data)
    }

    func currentSession(on server: ServerURL, stored: AuthenticatedSession) async throws -> AuthenticatedSession? {
        let (data, response) = try await send(Self.sessionRequest(on: server, stored: stored))
        return try Self.parseCurrentSession(response, data: data, stored: stored)
    }

    func logout(on server: ServerURL, session stored: AuthenticatedSession) async {
        _ = try? await send(Self.logoutRequest(on: server, session: stored))
    }

    func startSetup(on url: ServerURL, session stored: AuthenticatedSession) async throws -> AuthenticatorEnrollment {
        let (data, response) = try await send(Self.enrollRequest(on: url, session: stored))
        return try Self.parseEnroll(response, data: data)
    }

    func confirmSetup(on server: ServerURL, session stored: AuthenticatedSession, code: String) async throws {
        let (data, response) = try await send(Self.confirmRequest(on: server, session: stored, code: code))
        try Self.parseConfirm(response, data: data)
    }

    func stepUp(
        on url: ServerURL,
        session stored: AuthenticatedSession,
        kind: SecondFactorKind,
        code: String
    ) async throws {
        let (data, response) = try await send(Self.stepUpRequest(on: url, session: stored, kind: kind, code: code))
        try Self.parseStepUp(response, data: data)
    }

    func sendStepUpEmail(on url: ServerURL, session stored: AuthenticatedSession) async throws {
        let (data, response) = try await send(Self.stepUpEmailRequest(on: url, session: stored))
        try Self.parseStepUpEmail(response, data: data)
    }

    // MARK: Requests

    static func stepUpRequest(
        on server: ServerURL,
        session: AuthenticatedSession,
        kind: SecondFactorKind,
        code: String
    ) -> URLRequest {
        signedInPost("/auth/mfa/step-up", on: server, session: session, body: ["kind": kind.rawValue, "code": code])
    }

    static func stepUpEmailRequest(on server: ServerURL, session: AuthenticatedSession) -> URLRequest {
        signedInPost("/auth/mfa/step-up/email/send", on: server, session: session, body: [:])
    }

    static func loginRequest(to server: ServerURL, username: String, password: String) -> URLRequest {
        post("/auth/login", on: server, body: ["username": username, "password": password])
    }

    static func verifyRequest(
        on server: ServerURL,
        challenge: SecondFactorChallenge,
        kind: SecondFactorKind,
        code: String
    ) -> URLRequest {
        post(
            "/auth/verify-otp",
            on: server,
            body: ["pendingId": challenge.pendingID, "code": code, "kind": kind.rawValue]
        )
    }

    static func emailCodeRequest(on server: ServerURL, challenge: SecondFactorChallenge) -> URLRequest {
        post("/auth/mfa/otp/send", on: server, body: ["pendingId": challenge.pendingID])
    }

    static func sessionRequest(on server: ServerURL, stored: AuthenticatedSession) -> URLRequest {
        var request = request("/auth/session", on: server, method: "GET")
        request.setValue("\(cookieName)=\(stored.cookieValue)", forHTTPHeaderField: "Cookie")
        return request
    }

    static func logoutRequest(on server: ServerURL, session: AuthenticatedSession) -> URLRequest {
        var request = request("/auth/logout", on: server, method: "POST")
        request.setValue("\(cookieName)=\(session.cookieValue)", forHTTPHeaderField: "Cookie")
        request.setValue(session.csrfToken, forHTTPHeaderField: "X-CSRF-Token")
        return request
    }

    static func enrollRequest(on server: ServerURL, session: AuthenticatedSession) -> URLRequest {
        signedInPost("/auth/mfa/enroll", on: server, session: session, body: [:])
    }

    static func confirmRequest(on server: ServerURL, session: AuthenticatedSession, code: String) -> URLRequest {
        signedInPost("/auth/mfa/confirm", on: server, session: session, body: ["code": code])
    }

    private static func signedInPost(
        _ path: String,
        on server: ServerURL,
        session: AuthenticatedSession,
        body: [String: String]
    ) -> URLRequest {
        var request = post(path, on: server, body: body)
        request.setValue("\(cookieName)=\(session.cookieValue)", forHTTPHeaderField: "Cookie")
        request.setValue(session.csrfToken, forHTTPHeaderField: "X-CSRF-Token")
        return request
    }

    private static func request(_ path: String, on server: ServerURL, method: String) -> URLRequest {
        var request = URLRequest(url: server.origin.appending(path: path), timeoutInterval: timeout)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpShouldHandleCookies = false
        return request
    }

    private static func post(_ path: String, on server: ServerURL, body: [String: String]) -> URLRequest {
        var request = request(path, on: server, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(body)
        return request
    }

    private func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let path = request.url?.path ?? ""
        let started = Date()
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw AuthError.unexpected }
            let seconds = Date().timeIntervalSince(started)
            let status = http.statusCode
            Self.logger.debug("auth \(path, privacy: .public): \(status) in \(seconds, format: .fixed(precision: 2))s")
            return (data, http)
        } catch let error as AuthError {
            throw error
        } catch {
            Self.logger.info("auth \(path, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            throw AuthError.unreachable
        }
    }
}
