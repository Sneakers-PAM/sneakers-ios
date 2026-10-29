// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Sneakers_PAM
import Testing

struct HTTPAuthServiceTests {
    private let server = ServerURL.fixture
    private let challenge = SecondFactorChallenge(pendingID: "pending-1", factors: [.totp, .email])

    private func response(
        _ status: Int,
        path: String = "/auth/login",
        headers: [String: String] = [:]
    ) throws -> HTTPURLResponse {
        let url = try #require(URL(string: "https://one.example.org" + path))
        return try #require(HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: headers))
    }

    private let sessionCookie = ["Set-Cookie": "sneakers_sid=abc123; Path=/; HttpOnly; Secure; SameSite=Strict"]

    private func json(_ text: String) -> Data {
        Data(text.utf8)
    }

    private func body(of request: URLRequest) throws -> [String: String] {
        let data = try #require(request.httpBody)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: String])
    }

    // MARK: Requests

    @Test func loginIsAJSONPostToAuthLogin() throws {
        let request = HTTPAuthService.loginRequest(to: server, username: "alice", password: "pw")
        #expect(request.url?.absoluteString == "https://one.example.org/auth/login")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(try body(of: request) == ["username": "alice", "password": "pw"])
    }

    @Test func verifyPostsThePendingIdTheCodeAndTheKind() throws {
        let request = HTTPAuthService.verifyRequest(on: server, challenge: challenge, kind: .email, code: "123456")
        #expect(request.url?.path == "/auth/verify-otp")
        #expect(request.httpMethod == "POST")
        #expect(try body(of: request) == ["pendingId": "pending-1", "code": "123456", "kind": "email"])
    }

    @Test func theEmailCodeRequestPostsThePendingId() throws {
        let request = HTTPAuthService.emailCodeRequest(on: server, challenge: challenge)
        #expect(request.url?.path == "/auth/mfa/otp/send")
        #expect(request.httpMethod == "POST")
        #expect(try body(of: request) == ["pendingId": "pending-1"])
    }

    @Test func theSessionCheckSendsOnlyTheCookie() {
        let request = HTTPAuthService.sessionRequest(on: server, stored: .fixture(cookie: "abc123"))
        #expect(request.url?.path == "/auth/session")
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Cookie") == "sneakers_sid=abc123")
    }

    @Test func logoutSendsTheCookieAndTheCSRFToken() {
        let request = HTTPAuthService.logoutRequest(on: server, session: .fixture(cookie: "abc123", csrf: "tok"))
        #expect(request.url?.path == "/auth/logout")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Cookie") == "sneakers_sid=abc123")
        #expect(request.value(forHTTPHeaderField: "X-CSRF-Token") == "tok")
    }

    @Test func requestsNeverUseTheSharedCookieJar() {
        let request = HTTPAuthService.loginRequest(to: server, username: "alice", password: "pw")
        #expect(request.httpShouldHandleCookies == false)
    }

    @Test func startingSetupPostsWithTheCookieAndTheCSRFToken() {
        let request = HTTPAuthService.enrollRequest(on: server, session: .fixture(cookie: "abc123", csrf: "tok"))
        #expect(request.url?.path == "/auth/mfa/enroll")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Cookie") == "sneakers_sid=abc123")
        #expect(request.value(forHTTPHeaderField: "X-CSRF-Token") == "tok")
    }

    @Test func confirmingPostsTheCodeWithTheCookieAndTheCSRFToken() throws {
        let request = HTTPAuthService.confirmRequest(
            on: server,
            session: .fixture(cookie: "abc123", csrf: "tok"),
            code: "123456"
        )
        #expect(request.url?.path == "/auth/mfa/confirm")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Cookie") == "sneakers_sid=abc123")
        #expect(request.value(forHTTPHeaderField: "X-CSRF-Token") == "tok")
        #expect(try body(of: request) == ["code": "123456"])
    }
}
