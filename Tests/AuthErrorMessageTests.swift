// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

@testable import Sneakers_PAM
import Testing

struct AuthErrorMessageTests {
    @Test func eachFailureSaysWhatHappenedInPlainWords() {
        #expect(AuthError.invalidCredentials.message == "That username or password isn't right.")
        #expect(AuthError.accountDisabled.message == "This account is disabled. Ask your administrator.")
        #expect(AuthError.invalidCode.message == "That code didn't work. Check it and try again.")
        #expect(AuthError.attemptExpired.message == "That sign-in timed out. Enter your password again.")
        #expect(AuthError.rateLimited.message == "A code was just sent. Wait a moment before asking for another.")
        #expect(AuthError.unreachable.message == "Couldn't reach the server. Check your connection and try again.")
        #expect(AuthError.unexpected.message == "Something went wrong signing in. Try again.")
    }

    @Test func theAuthenticatorSetupFailuresHaveTheirOwnMessages() {
        #expect(AuthError.alreadyEnrolled.message == "An authenticator app is already set up for this account.")
        #expect(AuthError.mfaUnavailable.message == "Authenticator setup isn't available on this server.")
        #expect(AuthError.stepUpRequired
            .message == "For your security, sign in again before changing your second factor.")
        #expect(AuthError.sessionEnded.message == "Your session ended. Sign in again.")
    }

    @Test func theWrongCredentialsMessageDoesNotSayWhichPartWasWrong() {
        let message = AuthError.invalidCredentials.message.lowercased()
        #expect(message.contains("username"))
        #expect(message.contains("password"))
    }
}
