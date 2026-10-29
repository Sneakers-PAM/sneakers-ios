// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Sneakers_PAM
import Testing

struct HTTPAuthAnswerTests {
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

    // MARK: Login

    @Test func aPasswordOnlyAccountIsSignedInWithTheCookieAndTheCSRFToken() throws {
        let outcome = try HTTPAuthService.parseLogin(
            response(200, headers: sessionCookie),
            data: json(#"{"csrfToken":"c1","userId":"u1"}"#)
        )
        #expect(outcome == .signedIn(AuthenticatedSession(cookieValue: "abc123", csrfToken: "c1", userID: "u1")))
    }

    @Test func theEnrolmentFlagsAreKept() throws {
        let outcome = try HTTPAuthService.parseLogin(
            response(200, headers: sessionCookie),
            data: json(#"{"csrfToken":"c1","userId":"u1","mfaEnrollmentRequired":true}"#)
        )
        guard case let .signedIn(session) = outcome else {
            Issue.record("expected signedIn")
            return
        }
        #expect(session.enrolmentRequired)
        #expect(!session.setupRecommended)
    }

    @Test func theSetupReminderFlagIsKept() throws {
        let outcome = try HTTPAuthService.parseLogin(
            response(200, headers: sessionCookie),
            data: json(#"{"csrfToken":"c1","userId":"u1","mfaSetupRecommended":true}"#)
        )
        guard case let .signedIn(session) = outcome else {
            Issue.record("expected signedIn")
            return
        }
        #expect(session.setupRecommended)
    }

    @Test func aSecondFactorChallengeCarriesThePendingIdAndTheOfferedKinds() throws {
        let outcome = try HTTPAuthService.parseLogin(
            response(200),
            data: json(#"{"mfaRequired":true,"pendingId":"p1","factors":["totp","email","passkey","carrier-pigeon"]}"#)
        )
        #expect(outcome == .secondFactorRequired(SecondFactorChallenge(
            pendingID: "p1",
            factors: [.totp, .email, .passkey]
        )))
    }

    @Test func aSignedInAnswerWithoutTheCookieIsNotTrusted() throws {
        #expect(throws: AuthError.unexpected) {
            try HTTPAuthService.parseLogin(response(200), data: json(#"{"csrfToken":"c1","userId":"u1"}"#))
        }
    }

    @Test func loginFailuresMapToTheirMeaning() throws {
        #expect(throws: AuthError.invalidCredentials) {
            try HTTPAuthService.parseLogin(response(401), data: json(#"{"error":"invalid_credentials"}"#))
        }
        #expect(throws: AuthError.accountDisabled) {
            try HTTPAuthService.parseLogin(response(403), data: json(#"{"error":"account_disabled"}"#))
        }
        #expect(throws: AuthError.unreachable) {
            try HTTPAuthService.parseLogin(response(502), data: json(#"{"error":"auth_unreachable"}"#))
        }
        #expect(throws: AuthError.unreachable) {
            try HTTPAuthService.parseLogin(response(502), data: json(#"{"error":"identity_unreachable"}"#))
        }
        #expect(throws: AuthError.unexpected) {
            try HTTPAuthService.parseLogin(response(500), data: json(#"{"error":"server"}"#))
        }
    }

    // MARK: Second factor

    @Test func aCorrectCodeSignsInAndIssuesTheSessionCookie() throws {
        let session = try HTTPAuthService.parseVerify(
            response(200, path: "/auth/verify-otp", headers: sessionCookie),
            data: json(#"{"csrfToken":"c2","userId":"u1"}"#)
        )
        #expect(session == AuthenticatedSession(cookieValue: "abc123", csrfToken: "c2", userID: "u1"))
    }

    @Test func verifyFailuresMapToTheirMeaning() throws {
        #expect(throws: AuthError.invalidCode) {
            try HTTPAuthService.parseVerify(response(401), data: json(#"{"error":"invalid_code"}"#))
        }
        #expect(throws: AuthError.attemptExpired) {
            try HTTPAuthService.parseVerify(response(401), data: json(#"{"error":"invalid_pending"}"#))
        }
        #expect(throws: AuthError.unreachable) {
            try HTTPAuthService.parseVerify(response(502), data: json(#"{"error":"identity_unreachable"}"#))
        }
    }

    @Test func sendingAnEmailCodeSucceedsOnOK() throws {
        try HTTPAuthService.parseEmailCode(response(200), data: json(#"{"ok":true}"#))
    }

    @Test func emailCodeFailuresMapToTheirMeaning() throws {
        #expect(throws: AuthError.rateLimited) {
            try HTTPAuthService.parseEmailCode(response(429), data: json(#"{"error":"rate_limited"}"#))
        }
        #expect(throws: AuthError.attemptExpired) {
            try HTTPAuthService.parseEmailCode(response(401), data: json(#"{"error":"invalid_pending"}"#))
        }
        #expect(throws: AuthError.unreachable) {
            try HTTPAuthService.parseEmailCode(response(502), data: json(#"{"error":"identity_unreachable"}"#))
        }
    }

    // MARK: Authenticator setup

    @Test func aStartedSetupReturnsTheSecretAndTheAuthenticatorAddress() throws {
        let enrollment = try HTTPAuthService.parseEnroll(
            response(200, path: "/auth/mfa/enroll"),
            data: json(
                #"{"secret":"JBSWY3DPEHPK3PXP","otpauthUri":"otpauth://totp/Sneakers:alice?secret=JBSWY3DPEHPK3PXP"}"#
            )
        )
        #expect(enrollment == AuthenticatorEnrollment(
            secret: "JBSWY3DPEHPK3PXP",
            otpauthURI: "otpauth://totp/Sneakers:alice?secret=JBSWY3DPEHPK3PXP"
        ))
    }

    @Test func setupFailuresMapToTheirMeaning() throws {
        #expect(throws: AuthError.alreadyEnrolled) {
            try HTTPAuthService.parseEnroll(response(409), data: json(#"{"error":"already_enrolled"}"#))
        }
        #expect(throws: AuthError.mfaUnavailable) {
            try HTTPAuthService.parseEnroll(response(503), data: json(#"{"error":"mfa_unavailable"}"#))
        }
        #expect(throws: AuthError.stepUpRequired) {
            try HTTPAuthService.parseEnroll(response(403), data: json(#"{"error":"step_up_required"}"#))
        }
        #expect(throws: AuthError.sessionEnded) {
            try HTTPAuthService.parseEnroll(response(401), data: json(#"{"error":"no_session"}"#))
        }
        #expect(throws: AuthError.unreachable) {
            try HTTPAuthService.parseEnroll(response(502), data: json(#"{"error":"identity_unreachable"}"#))
        }
    }

    @Test func aSetupAnswerWithoutTheSecretIsNotTrusted() throws {
        #expect(throws: AuthError.unexpected) {
            try HTTPAuthService.parseEnroll(response(200), data: json(#"{"otpauthUri":"otpauth://totp/x"}"#))
        }
    }

    @Test func confirmingSucceedsOnOK() throws {
        try HTTPAuthService.parseConfirm(response(200), data: json(#"{"ok":true}"#))
    }

    @Test func confirmFailuresMapToTheirMeaning() throws {
        #expect(throws: AuthError.invalidCode) {
            try HTTPAuthService.parseConfirm(response(400), data: json(#"{"error":"invalid_code"}"#))
        }
        #expect(throws: AuthError.mfaUnavailable) {
            try HTTPAuthService.parseConfirm(response(503), data: json(#"{"error":"mfa_unavailable"}"#))
        }
        #expect(throws: AuthError.sessionEnded) {
            try HTTPAuthService.parseConfirm(response(401), data: json(#"{"error":"no_session"}"#))
        }
        #expect(throws: AuthError.unreachable) {
            try HTTPAuthService.parseConfirm(response(502), data: json(#"{"error":"identity_unreachable"}"#))
        }
    }

    // MARK: Session

    @Test func aSessionThatIsNoLongerSignedInIsNil() throws {
        let stored = AuthenticatedSession.fixture(cookie: "abc123")
        let answer = try HTTPAuthService.parseCurrentSession(
            response(200, path: "/auth/session"),
            data: json(#"{"authenticated":false}"#),
            stored: stored
        )
        #expect(answer == nil)
    }

    @Test func aRejectedSessionIsNil() throws {
        let answer = try HTTPAuthService.parseCurrentSession(
            response(401, path: "/auth/session"),
            data: json(#"{"error":"no_session"}"#),
            stored: .fixture()
        )
        #expect(answer == nil)
    }

    @Test func aLiveSessionKeepsItsCookieAndTakesTheFreshTokenAndFlags() throws {
        let stored = AuthenticatedSession.fixture(cookie: "abc123", csrf: "old", user: "u1")
        let answer = try HTTPAuthService.parseCurrentSession(
            response(200, path: "/auth/session"),
            data: json(#"{"authenticated":true,"csrfToken":"fresh","userId":"u1","mfaSetupRecommended":true}"#),
            stored: stored
        )
        #expect(answer == AuthenticatedSession(
            cookieValue: "abc123",
            csrfToken: "fresh",
            userID: "u1",
            setupRecommended: true
        ))
    }

    @Test func aLiveSessionKeepsTheUsernameItWasSavedWith() throws {
        var stored = AuthenticatedSession.fixture(cookie: "abc123")
        stored.username = "alice"
        let answer = try HTTPAuthService.parseCurrentSession(
            response(200, path: "/auth/session"),
            data: json(#"{"authenticated":true,"csrfToken":"fresh","userId":"u-1"}"#),
            stored: stored
        )
        #expect(answer?.username == "alice")
    }

    @Test func anUnreachableServerWhileCheckingTheSessionIsAnError() throws {
        #expect(throws: AuthError.unreachable) {
            try HTTPAuthService.parseCurrentSession(
                response(502, path: "/auth/session"),
                data: Data(),
                stored: .fixture()
            )
        }
    }
}
