// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Sneakers_PAM
import Testing

@MainActor
struct AuthenticatorSetupModelTests {
    private final class Done {
        var calls = 0
    }

    private let auth = FakeAuthService()
    private let done = Done()
    private let server = ServerEntry.fixture()
    private let enrollment = AuthenticatorEnrollment(
        secret: "JBSWY3DPEHPK3PXP",
        otpauthURI: "otpauth://totp/x?secret=JBSWY3DPEHPK3PXP"
    )

    private func makeModel() -> AuthenticatorSetupModel {
        let done = done
        return AuthenticatorSetupModel(server: server, session: .fixture(), auth: auth) { done.calls += 1 }
    }

    @Test func startsPreparing() {
        let model = makeModel()
        #expect(model.step == .preparing)
        #expect(model.message == nil)
    }

    @Test func startingSetupShowsTheSecretToScan() async {
        auth.enrollResult = .success(enrollment)
        let model = makeModel()

        await model.start()

        #expect(model.step == .scan(enrollment))
        #expect(auth.enrollStarts == 1)
    }

    @Test func aSetupThatCannotStartSaysWhy() async {
        auth.enrollResult = .failure(.alreadyEnrolled)
        let model = makeModel()

        await model.start()

        #expect(model.step == .failed)
        #expect(model.message == AuthError.alreadyEnrolled.message)
    }

    @Test func aCodeThatIsNotSixDigitsIsRefusedWithoutAskingTheServer() async {
        auth.enrollResult = .success(enrollment)
        let model = makeModel()
        await model.start()

        await model.confirm(code: "12345")
        #expect(model.message == "Enter the 6-digit code.")
        await model.confirm(code: "abcdef")
        #expect(model.message == "Enter the 6-digit code.")

        #expect(auth.confirmCodes.isEmpty)
    }

    @Test func aCorrectCodeFinishesSetupOnce() async {
        auth.enrollResult = .success(enrollment)
        let model = makeModel()
        await model.start()

        await model.confirm(code: "123456")

        #expect(auth.confirmCodes == ["123456"])
        #expect(done.calls == 1)
        #expect(model.isEnrolled)
        #expect(model.message == nil)
    }

    @Test func aWrongCodeShowsAMessageAndKeepsTheSecretOnScreen() async {
        auth.enrollResult = .success(enrollment)
        auth.confirmResult = .failure(.invalidCode)
        let model = makeModel()
        await model.start()

        await model.confirm(code: "123456")

        #expect(model.message == AuthError.invalidCode.message)
        #expect(model.step == .scan(enrollment))
        #expect(done.calls == 0)
    }

    @Test func anEndedSessionShowsAMessage() async {
        auth.enrollResult = .success(enrollment)
        auth.confirmResult = .failure(.sessionEnded)
        let model = makeModel()
        await model.start()

        await model.confirm(code: "123456")

        #expect(model.message == AuthError.sessionEnded.message)
    }

    @Test func confirmingBeforeSetupHasStartedDoesNothing() async {
        let model = makeModel()

        await model.confirm(code: "123456")

        #expect(auth.confirmCodes.isEmpty)
    }
}
