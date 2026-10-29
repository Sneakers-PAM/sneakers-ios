// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// How the gateway's answers are read. Kept apart from the requests so each part stays small and is tested alone.
extension HTTPAuthService {
    // MARK: Answers

    static func parseLogin(_ response: HTTPURLResponse, data: Data) throws -> LoginOutcome {
        switch response.statusCode {
        case 200:
            let body = try decode(Body.self, from: data)
            if body.mfaRequired == true, let pendingID = body.pendingId {
                let factors = (body.factors ?? []).compactMap(SecondFactorKind.init(rawValue:))
                return .secondFactorRequired(SecondFactorChallenge(pendingID: pendingID, factors: factors))
            }
            return try .signedIn(signedIn(response, body))
        case 401 where errorKey(data) == "invalid_credentials":
            throw AuthError.invalidCredentials
        case 403 where errorKey(data) == "account_disabled":
            throw AuthError.accountDisabled
        default:
            throw failure(for: response.statusCode)
        }
    }

    static func parseVerify(_ response: HTTPURLResponse, data: Data) throws -> AuthenticatedSession {
        switch response.statusCode {
        case 200:
            try signedIn(response, decode(Body.self, from: data))
        case 401 where errorKey(data) == "invalid_code":
            throw AuthError.invalidCode
        case 401 where errorKey(data) == "invalid_pending":
            throw AuthError.attemptExpired
        default:
            throw failure(for: response.statusCode)
        }
    }

    static func parseEmailCode(_ response: HTTPURLResponse, data: Data) throws {
        switch response.statusCode {
        case 200:
            return
        case 429:
            throw AuthError.rateLimited
        case 401 where errorKey(data) == "invalid_pending":
            throw AuthError.attemptExpired
        default:
            throw failure(for: response.statusCode)
        }
    }

    static func parseEnroll(_ response: HTTPURLResponse, data: Data) throws -> AuthenticatorEnrollment {
        switch response.statusCode {
        case 200:
            let body = try decode(Body.self, from: data)
            guard let secret = body.secret, let uri = body.otpauthUri else { throw AuthError.unexpected }
            return AuthenticatorEnrollment(secret: secret, otpauthURI: uri)
        case 401:
            throw AuthError.sessionEnded
        case 403 where errorKey(data) == "step_up_required":
            throw AuthError.stepUpRequired
        case 409:
            throw AuthError.alreadyEnrolled
        case 503:
            throw AuthError.mfaUnavailable
        default:
            throw failure(for: response.statusCode)
        }
    }

    static func parseConfirm(_ response: HTTPURLResponse, data: Data) throws {
        switch response.statusCode {
        case 200:
            return
        case 400 where errorKey(data) == "invalid_code":
            throw AuthError.invalidCode
        case 401:
            throw AuthError.sessionEnded
        case 503:
            throw AuthError.mfaUnavailable
        default:
            throw failure(for: response.statusCode)
        }
    }

    static func parseStepUp(_ response: HTTPURLResponse, data: Data) throws {
        switch response.statusCode {
        case 200:
            return
        case 401 where errorKey(data) == "invalid_code":
            throw AuthError.invalidCode
        case 401:
            throw AuthError.sessionEnded
        case 429:
            throw AuthError.rateLimited
        default:
            throw failure(for: response.statusCode)
        }
    }

    static func parseStepUpEmail(_ response: HTTPURLResponse, data _: Data) throws {
        switch response.statusCode {
        case 200:
            return
        case 401:
            throw AuthError.sessionEnded
        case 429:
            throw AuthError.rateLimited
        default:
            throw failure(for: response.statusCode)
        }
    }

    static func parseCurrentSession(
        _ response: HTTPURLResponse,
        data: Data,
        stored: AuthenticatedSession
    ) throws -> AuthenticatedSession? {
        switch response.statusCode {
        case 200:
            let body = try decode(Body.self, from: data)
            guard body.authenticated == true, let csrf = body.csrfToken, let userID = body.userId else { return nil }
            return AuthenticatedSession(
                cookieValue: stored.cookieValue,
                csrfToken: csrf,
                userID: userID,
                enrolmentRequired: body.mfaEnrollmentRequired ?? false,
                setupRecommended: body.mfaSetupRecommended ?? false,
                username: stored.username
            )
        case 401, 403:
            return nil
        default:
            throw failure(for: response.statusCode)
        }
    }

    // MARK: Helpers

    private struct Body: Decodable {
        var authenticated: Bool?
        var csrfToken: String?
        var userId: String?
        var mfaRequired: Bool?
        var pendingId: String?
        var factors: [String]?
        var mfaEnrollmentRequired: Bool?
        var mfaSetupRecommended: Bool?
        var secret: String?
        var otpauthUri: String?
        var error: String?
    }

    private static func signedIn(_ response: HTTPURLResponse, _ body: Body) throws -> AuthenticatedSession {
        guard let csrf = body.csrfToken, let userID = body.userId, let cookie = sessionCookie(from: response) else {
            throw AuthError.unexpected
        }
        return AuthenticatedSession(
            cookieValue: cookie,
            csrfToken: csrf,
            userID: userID,
            enrolmentRequired: body.mfaEnrollmentRequired ?? false,
            setupRecommended: body.mfaSetupRecommended ?? false
        )
    }

    private static func sessionCookie(from response: HTTPURLResponse) -> String? {
        guard let url = response.url else { return nil }
        var fields: [String: String] = [:]
        for (key, value) in response.allHeaderFields {
            if let key = key as? String, let value = value as? String {
                fields[key] = value
            }
        }
        return HTTPCookie.cookies(withResponseHeaderFields: fields, for: url).first { $0.name == cookieName }?.value
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw AuthError.unexpected
        }
    }

    private static func errorKey(_ data: Data) -> String? {
        try? JSONDecoder().decode(Body.self, from: data).error
    }

    private static func failure(for status: Int) -> AuthError {
        (502 ... 504).contains(status) ? .unreachable : .unexpected
    }
}
