// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Sneakers_PAM
import Testing

@MainActor
struct SessionManagerTests {
    private let auth = FakeAuthService()
    private let store = InMemorySessionStore()
    private let server = ServerEntry.fixture()

    private func makeManager() -> SessionManager {
        SessionManager(auth: auth, store: store)
    }

    @Test func startsSignedOut() {
        let manager = makeManager()
        #expect(!manager.isSignedIn(server.id))
        #expect(manager.session(for: server.id) == nil)
    }

    @Test func signingInSavesTheSessionAndMarksTheServerSignedIn() {
        let manager = makeManager()
        manager.signedIn(.fixture(), for: server)

        #expect(manager.isSignedIn(server.id))
        #expect(store.sessions[server.id] == .fixture())
    }

    @Test func restoringWithNothingSavedStaysSignedOutWithoutAskingTheServer() async {
        let manager = makeManager()

        let result = await manager.restore(server)

        #expect(result == .signedOut)
        #expect(auth.currentChecks == 0)
    }

    @Test func aSavedSessionTheServerStillAcceptsSignsInAndTakesTheFreshToken() async {
        store.save(.fixture(csrf: "old"), for: server.id)
        auth.currentResult = .success(.fixture(csrf: "fresh"))
        let manager = makeManager()

        let result = await manager.restore(server)

        #expect(result == .signedIn)
        #expect(manager.session(for: server.id)?.csrfToken == "fresh")
        #expect(store.sessions[server.id]?.csrfToken == "fresh")
    }

    @Test func aSavedSessionTheServerRefusesIsClearedFromTheStore() async {
        store.save(.fixture(), for: server.id)
        auth.currentResult = .success(nil)
        let manager = makeManager()

        let result = await manager.restore(server)

        #expect(result == .signedOut)
        #expect(!manager.isSignedIn(server.id))
        #expect(store.sessions[server.id] == nil)
    }

    @Test func anUnreachableServerKeepsTheSavedSessionButDoesNotSignIn() async {
        store.save(.fixture(), for: server.id)
        auth.currentResult = .failure(.unreachable)
        let manager = makeManager()

        let result = await manager.restore(server)

        #expect(result == .unreachable)
        #expect(!manager.isSignedIn(server.id))
        #expect(store.sessions[server.id] != nil)
    }

    @Test func signingOutEndsTheSessionClearsTheStoreAndForgetsTheServerSignedIn() async {
        let manager = makeManager()
        manager.signedIn(.fixture(), for: server)

        await manager.signOut(server)

        #expect(auth.logouts == 1)
        #expect(!manager.isSignedIn(server.id))
        #expect(store.sessions[server.id] == nil)
    }

    @Test func signingOutWithoutASessionDoesNotCallTheServer() async {
        let manager = makeManager()

        await manager.signOut(server)

        #expect(auth.logouts == 0)
    }

    @Test func forgettingAServerClearsItsSavedSession() {
        let manager = makeManager()
        manager.signedIn(.fixture(), for: server)

        manager.forget(server.id)

        #expect(!manager.isSignedIn(server.id))
        #expect(store.sessions[server.id] == nil)
    }

    @Test func thereIsNoSetupModelWithoutASession() {
        #expect(makeManager().makeAuthenticatorSetupModel(for: server) == nil)
    }

    @Test func finishingSetupTakesTheNewSessionStateFromTheServer() async throws {
        let enrollment = AuthenticatorEnrollment(
            secret: "JBSWY3DPEHPK3PXP",
            otpauthURI: "otpauth://totp/x?secret=JBSWY3DPEHPK3PXP"
        )
        auth.enrollResult = .success(enrollment)
        auth.currentResult = .success(AuthenticatedSession(cookieValue: "c", csrfToken: "t", userID: "u"))
        let manager = makeManager()
        manager.signedIn(
            AuthenticatedSession(cookieValue: "c", csrfToken: "t", userID: "u", enrolmentRequired: true),
            for: server
        )
        let model = try #require(manager.makeAuthenticatorSetupModel(for: server))

        await model.start()
        await model.confirm(code: "123456")

        #expect(manager.session(for: server.id)?.enrolmentRequired == false)
        #expect(model.isEnrolled)
    }

    @Test func refreshingTakesTheFreshFlagsFromTheServer() async {
        let manager = makeManager()
        manager.signedIn(
            AuthenticatedSession(cookieValue: "c", csrfToken: "t", userID: "u", enrolmentRequired: true),
            for: server
        )
        auth.currentResult = .success(AuthenticatedSession(cookieValue: "c", csrfToken: "t2", userID: "u"))

        await manager.refresh(server)

        #expect(manager.session(for: server.id)?.enrolmentRequired == false)
        #expect(store.sessions[server.id]?.csrfToken == "t2")
    }

    @Test func refreshingASessionTheServerRefusesSignsOut() async {
        let manager = makeManager()
        manager.signedIn(.fixture(), for: server)
        auth.currentResult = .success(nil)

        await manager.refresh(server)

        #expect(!manager.isSignedIn(server.id))
        #expect(store.sessions[server.id] == nil)
    }

    @Test func refreshingWhenTheServerCannotBeReachedChangesNothing() async {
        let manager = makeManager()
        manager.signedIn(.fixture(), for: server)
        auth.currentResult = .failure(.unreachable)

        await manager.refresh(server)

        #expect(manager.isSignedIn(server.id))
    }

    @Test func onlyASignInByHandCountsAsInteractive() async {
        store.save(.fixture(), for: server.id)
        auth.currentResult = .success(.fixture())
        let manager = makeManager()

        _ = await manager.restore(server)
        #expect(manager.interactiveSignIns == 0)

        manager.signedIn(.fixture(), for: server)
        #expect(manager.interactiveSignIns == 1)
    }

    @Test func theSameSignInModelIsHandedBackUntilThePersonSignsIn() {
        let manager = makeManager()

        let first = manager.makeSignInModel(for: server)
        let again = manager.makeSignInModel(for: server)

        #expect(first === again)
    }

    @Test func afterSigningInOrOutTheNextSignInStartsFresh() async {
        let manager = makeManager()
        let first = manager.makeSignInModel(for: server)

        manager.signedIn(.fixture(), for: server)
        await manager.signOut(server)

        #expect(manager.makeSignInModel(for: server) !== first)
    }

    @Test func signingInThroughTheModelMarksTheServerSignedIn() async {
        auth.loginResult = .success(.signedIn(.fixture()))
        let manager = makeManager()

        await manager.makeSignInModel(for: server).submit(username: "alice", password: "pw")

        #expect(manager.isSignedIn(server.id))
        #expect(store.sessions[server.id]?.cookieValue == AuthenticatedSession.fixture().cookieValue)
        #expect(store.sessions[server.id]?.username == "alice")
    }

    @Test func eachServerHasItsOwnSession() {
        let other = ServerEntry.fixture(host: "two.example.org")
        let manager = makeManager()
        manager.signedIn(.fixture(cookie: "one"), for: server)

        #expect(manager.isSignedIn(server.id))
        #expect(!manager.isSignedIn(other.id))
    }
}
