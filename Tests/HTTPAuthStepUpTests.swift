// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Sneakers_PAM
import Testing

struct HTTPAuthStepUpTests {
    private let server = ServerURL.fixture

    private func response(_ status: Int) throws -> HTTPURLResponse {
        let url = try #require(URL(string: "https://one.example.org/auth/mfa/step-up"))
        return try #require(HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: [:]))
    }

    private func json(_ text: String) -> Data {
        Data(text.utf8)
    }

    @Test func provingAFactorPostsTheKindAndTheCodeWithTheCookieAndTheCSRFToken() throws {
        let session = AuthenticatedSession.fixture(cookie: "abc123", csrf: "tok")
        let request = HTTPAuthService.stepUpRequest(on: server, session: session, kind: .email, code: "123456")

        #expect(request.url?.path == "/auth/mfa/step-up")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Cookie") == "sneakers_sid=abc123")
        #expect(request.value(forHTTPHeaderField: "X-CSRF-Token") == "tok")
        let body = try #require(request.httpBody)
        let object = try #require(try JSONSerialization.jsonObject(with: body) as? [String: String])
        #expect(object == ["kind": "email", "code": "123456"])
    }

    @Test func askingForAnEmailedCodePostsWithTheCookieAndTheCSRFToken() {
        let session = AuthenticatedSession.fixture(cookie: "abc123", csrf: "tok")
        let request = HTTPAuthService.stepUpEmailRequest(on: server, session: session)

        #expect(request.url?.path == "/auth/mfa/step-up/email/send")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Cookie") == "sneakers_sid=abc123")
        #expect(request.value(forHTTPHeaderField: "X-CSRF-Token") == "tok")
    }

    @Test func aProvenFactorSucceeds() throws {
        try HTTPAuthService.parseStepUp(response(200), data: json(#"{"mfaVerifiedAt":1793188800}"#))
    }

    @Test func stepUpFailuresMapToTheirMeaning() throws {
        #expect(throws: AuthError.invalidCode) {
            try HTTPAuthService.parseStepUp(response(401), data: json(#"{"error":"invalid_code"}"#))
        }
        #expect(throws: AuthError.sessionEnded) {
            try HTTPAuthService.parseStepUp(response(401), data: json(#"{"error":"session_revoked"}"#))
        }
        #expect(throws: AuthError.sessionEnded) {
            try HTTPAuthService.parseStepUp(response(401), data: json(#"{"error":"no_session"}"#))
        }
        #expect(throws: AuthError.unreachable) {
            try HTTPAuthService.parseStepUp(response(502), data: json(#"{"error":"identity_unreachable"}"#))
        }
    }

    @Test func theEmailedCodeAnswersMapToTheirMeaning() throws {
        try HTTPAuthService.parseStepUpEmail(response(200), data: json(#"{"ok":true}"#))
        #expect(throws: AuthError.rateLimited) {
            try HTTPAuthService.parseStepUpEmail(response(429), data: json(#"{"error":"rate_limited"}"#))
        }
        #expect(throws: AuthError.sessionEnded) {
            try HTTPAuthService.parseStepUpEmail(response(401), data: json(#"{"error":"no_session"}"#))
        }
        #expect(throws: AuthError.unexpected) {
            try HTTPAuthService.parseStepUpEmail(response(400), data: json(#"{"error":"no_email"}"#))
        }
    }
}
