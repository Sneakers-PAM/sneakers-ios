// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// The kinds of second factor a server can offer at sign-in.
nonisolated enum SecondFactorKind: String, Equatable, Sendable {
    case totp
    case email
    case passkey

    /// The factors this version of the app can complete. Passkeys need the Associated Domains entitlement.
    static let supported: [SecondFactorKind] = [.totp, .email]
}

/// A signed-in session on one server: the session cookie value, the CSRF token and who it is for.
nonisolated struct AuthenticatedSession: Equatable, Codable, Sendable {
    var cookieValue: String
    var csrfToken: String
    var userID: String
    var enrolmentRequired = false
    var setupRecommended = false
    /// The name typed at sign-in, kept with the session so Account can say who is signed in.
    var username: String?
}

/// The password was right and a second factor is owed. The pending id ties the code to this attempt.
nonisolated struct SecondFactorChallenge: Equatable, Sendable {
    let pendingID: String
    let factors: [SecondFactorKind]
}

/// What the server hands out to set up an authenticator app: the shared secret and the address behind the QR code.
nonisolated struct AuthenticatorEnrollment: Equatable, Sendable {
    let secret: String
    let otpauthURI: String
}

nonisolated enum LoginOutcome: Equatable, Sendable {
    case signedIn(AuthenticatedSession)
    case secondFactorRequired(SecondFactorChallenge)
}

nonisolated enum AuthError: Error, Equatable, Sendable {
    case invalidCredentials
    case accountDisabled
    case invalidCode
    case attemptExpired
    case rateLimited
    case unreachable
    case unexpected
    case alreadyEnrolled
    case mfaUnavailable
    case stepUpRequired
    case sessionEnded

    /// What to tell the person. It never says which of the username or password was wrong.
    var message: String {
        switch self {
        case .alreadyEnrolled: "An authenticator app is already set up for this account."
        case .mfaUnavailable: "Authenticator setup isn't available on this server."
        case .stepUpRequired: "For your security, sign in again before changing your second factor."
        case .sessionEnded: "Your session ended. Sign in again."
        case .invalidCredentials: "That username or password isn't right."
        case .accountDisabled: "This account is disabled. Ask your administrator."
        case .invalidCode: "That code didn't work. Check it and try again."
        case .attemptExpired: "That sign-in timed out. Enter your password again."
        case .rateLimited: "A code was just sent. Wait a moment before asking for another."
        case .unreachable: "Couldn't reach the server. Check your connection and try again."
        case .unexpected: "Something went wrong signing in. Try again."
        }
    }
}
