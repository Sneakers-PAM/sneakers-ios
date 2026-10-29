// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Sneakers_PAM
import Testing

@MainActor
struct SignInModelTests {
    private final class Signed {
        var sessions: [AuthenticatedSession] = []
    }

    private let auth = FakeAuthService()
    private let signed = Signed()
    private let server = ServerEntry.fixture()

    private func makeModel() -> SignInModel {
        let signed = signed
        return SignInModel(server: server, auth: auth) { signed.sessions.append($0) }
    }

    private func challenge(_ factors: [SecondFactorKind]) -> LoginOutcome {
        .secondFactorRequired(SecondFactorChallenge(pendingID: "pending-1", factors: factors))
    }

    // MARK: Password step

    @Test func startsOnTheCredentialsStep() {
        let model = makeModel()
        #expect(model.step == .credentials)
        #expect(model.message == nil)
        #expect(!model.isWorking)
    }

    @Test func aMissingUsernameOrPasswordIsRefusedWithoutAskingTheServer() async {
        let model = makeModel()

        await model.submit(username: "  ", password: "pw")
        #expect(model.message == "Enter your username and password.")
        await model.submit(username: "alice", password: "")
        #expect(model.message == "Enter your username and password.")

        #expect(auth.loginUsernames.isEmpty)
    }

    private func fixture(username: String = "alice", cookie: String = "cookie-1") -> AuthenticatedSession {
        var session = AuthenticatedSession.fixture(cookie: cookie)
        session.username = username
        return session
    }

    @Test func theUsernameIsKeptWithTheSessionForTheAccountScreen() async {
        auth.loginResult = .success(.signedIn(.fixture()))
        let model = makeModel()

        await model.submit(username: "  alice ", password: "pw")

        #expect(signed.sessions.first?.username == "alice")
    }

    @Test func theUsernameSurvivesTheSecondFactorStep() async {
        auth.loginResult = .success(challenge([.totp]))
        auth.verifyResult = .success(.fixture())
        let model = makeModel()
        await model.submit(username: "alice", password: "pw")

        await model.submitCode("123456")

        #expect(signed.sessions.first?.username == "alice")
    }

    @Test func aPasswordOnlyAccountSignsInStraightAway() async {
        auth.loginResult = .success(.signedIn(.fixture()))
        let model = makeModel()

        await model.submit(username: "alice", password: "pw")

        #expect(signed.sessions == [fixture()])
        #expect(model.step == .credentials)
        #expect(model.message == nil)
    }

    @Test func theUsernameIsTrimmedBeforeItIsSent() async {
        auth.loginResult = .success(.signedIn(.fixture()))
        let model = makeModel()

        await model.submit(username: "  alice ", password: "pw")

        #expect(auth.loginUsernames == ["alice"])
    }

    @Test func wrongCredentialsShowAMessageAndSignNobodyIn() async {
        auth.loginResult = .failure(.invalidCredentials)
        let model = makeModel()

        await model.submit(username: "alice", password: "bad")

        #expect(model.message == AuthError.invalidCredentials.message)
        #expect(signed.sessions.isEmpty)
        #expect(!model.isWorking)
    }

    @Test func anUnreachableServerShowsAMessage() async {
        auth.loginResult = .failure(.unreachable)
        let model = makeModel()

        await model.submit(username: "alice", password: "pw")

        #expect(model.message == AuthError.unreachable.message)
    }

    // MARK: Second factor step

    @Test func aSecondFactorMovesToTheCodeStepWithTheAuthenticatorFirst() async {
        auth.loginResult = .success(challenge([.email, .totp]))
        let model = makeModel()

        await model.submit(username: "alice", password: "pw")

        guard case let .secondFactor(challenge, selected) = model.step else {
            Issue.record("expected the code step")
            return
        }
        #expect(challenge.pendingID == "pending-1")
        #expect(selected == .totp)
        #expect(auth.emailSends == 0)
    }

    @Test func whenOnlyEmailIsOfferedTheCodeIsSentAtOnce() async {
        auth.loginResult = .success(challenge([.email]))
        let model = makeModel()

        await model.submit(username: "alice", password: "pw")

        guard case let .secondFactor(_, selected) = model.step else {
            Issue.record("expected the code step")
            return
        }
        #expect(selected == .email)
        #expect(auth.emailSends == 1)
    }

    @Test func aPasskeyIsNotOfferedButAnotherFactorStillIs() async {
        auth.loginResult = .success(challenge([.passkey, .totp]))
        let model = makeModel()

        await model.submit(username: "alice", password: "pw")

        guard case let .secondFactor(_, selected) = model.step else {
            Issue.record("expected the code step")
            return
        }
        #expect(selected == .totp)
        #expect(model.availableFactors == [.totp])
    }

    @Test func anAccountThatOnlyHasAPasskeyIsToldThisVersionCannotUseIt() async {
        auth.loginResult = .success(challenge([.passkey]))
        let model = makeModel()

        await model.submit(username: "alice", password: "pw")

        #expect(model.step == .credentials)
        #expect(model.message == "This account signs in with a passkey, which this version can't use yet.")
    }

    @Test func aCorrectCodeSignsIn() async {
        auth.loginResult = .success(challenge([.totp]))
        auth.verifyResult = .success(.fixture(cookie: "after-code"))
        let model = makeModel()
        await model.submit(username: "alice", password: "pw")

        await model.submitCode("123456")

        #expect(auth.verifications.count == 1)
        #expect(auth.verifications.first?.kind == .totp)
        #expect(auth.verifications.first?.code == "123456")
        #expect(signed.sessions == [fixture(cookie: "after-code")])
    }

    @Test func aCodeThatIsNotSixDigitsIsRefusedWithoutAskingTheServer() async {
        auth.loginResult = .success(challenge([.totp]))
        let model = makeModel()
        await model.submit(username: "alice", password: "pw")

        await model.submitCode("12345")
        #expect(model.message == "Enter the 6-digit code.")
        await model.submitCode("12a456")
        #expect(model.message == "Enter the 6-digit code.")

        #expect(auth.verifications.isEmpty)
    }

    @Test func aWrongCodeShowsAMessageAndStaysOnTheCodeStep() async {
        auth.loginResult = .success(challenge([.totp]))
        auth.verifyResult = .failure(.invalidCode)
        let model = makeModel()
        await model.submit(username: "alice", password: "pw")

        await model.submitCode("123456")

        #expect(model.message == AuthError.invalidCode.message)
        guard case .secondFactor = model.step else {
            Issue.record("expected to stay on the code step")
            return
        }
        #expect(signed.sessions.isEmpty)
    }

    @Test func anExpiredAttemptSendsThePersonBackToThePassword() async {
        auth.loginResult = .success(challenge([.totp]))
        auth.verifyResult = .failure(.attemptExpired)
        let model = makeModel()
        await model.submit(username: "alice", password: "pw")

        await model.submitCode("123456")

        #expect(model.step == .credentials)
        #expect(model.message == AuthError.attemptExpired.message)
    }

    @Test func choosingEmailSendsTheCodeAndSelectsIt() async {
        auth.loginResult = .success(challenge([.totp, .email]))
        let model = makeModel()
        await model.submit(username: "alice", password: "pw")

        await model.choose(.email)

        guard case let .secondFactor(_, selected) = model.step else {
            Issue.record("expected the code step")
            return
        }
        #expect(selected == .email)
        #expect(auth.emailSends == 1)
    }

    @Test func choosingTheAuthenticatorDoesNotSendAnything() async {
        auth.loginResult = .success(challenge([.totp, .email]))
        let model = makeModel()
        await model.submit(username: "alice", password: "pw")
        await model.choose(.email)

        await model.choose(.totp)

        guard case let .secondFactor(_, selected) = model.step else {
            Issue.record("expected the code step")
            return
        }
        #expect(selected == .totp)
        #expect(auth.emailSends == 1)
    }

    @Test func aFactorThatWasNotOfferedCannotBeChosen() async {
        auth.loginResult = .success(challenge([.totp]))
        let model = makeModel()
        await model.submit(username: "alice", password: "pw")

        await model.choose(.email)

        guard case let .secondFactor(_, selected) = model.step else {
            Issue.record("expected the code step")
            return
        }
        #expect(selected == .totp)
        #expect(auth.emailSends == 0)
    }

    @Test func askingForAnotherEmailTooSoonShowsAMessage() async {
        auth.loginResult = .success(challenge([.email]))
        auth.emailResult = .failure(.rateLimited)
        let model = makeModel()

        await model.submit(username: "alice", password: "pw")

        #expect(model.message == AuthError.rateLimited.message)
    }

    @Test func goingBackReturnsToTheCredentialsAndClearsTheMessage() async {
        auth.loginResult = .success(challenge([.totp]))
        auth.verifyResult = .failure(.invalidCode)
        let model = makeModel()
        await model.submit(username: "alice", password: "pw")
        await model.submitCode("123456")

        model.back()

        #expect(model.step == .credentials)
        #expect(model.message == nil)
    }

    @Test func aNewAttemptClearsTheOldMessage() async {
        auth.loginResult = .failure(.invalidCredentials)
        let model = makeModel()
        await model.submit(username: "alice", password: "bad")
        #expect(model.message != nil)

        auth.loginResult = .success(.signedIn(.fixture()))
        await model.submit(username: "alice", password: "good")

        #expect(model.message == nil)
    }
}
