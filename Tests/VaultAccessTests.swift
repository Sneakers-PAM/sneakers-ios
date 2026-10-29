// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Sneakers_PAM
import Testing

@MainActor
struct VaultAccessTests {
    private final class Ended {
        var calls = 0
    }

    private let vault = FakeVaultService()
    private let ended = Ended()

    private func makeAccess(context: ServerContext? = .fixture) -> VaultAccess {
        let ended = ended
        return VaultAccess(service: vault, context: { context }, onSessionEnded: { ended.calls += 1 })
    }

    @Test func theContextComesFromTheActiveServerAndSession() throws {
        let context = try makeAccess().context()

        #expect(context.server == ServerURL.fixture)
        #expect(context.session.userID == "me")
    }

    @Test func withNoSessionThereIsNoContext() {
        #expect(throws: VaultError.sessionEnded) { try makeAccess(context: nil).context() }
    }

    @Test func performRunsTheWorkWithTheContext() async throws {
        let userID = try await makeAccess().perform { $0.session.userID }

        #expect(userID == "me")
    }

    @Test func anEndedSessionIsReportedOnceAndStillThrown() async {
        let access = makeAccess()

        await #expect(throws: VaultError.sessionEnded) {
            try await access.perform { _ -> Int in throw VaultError.sessionEnded }
        }

        #expect(ended.calls == 1)
    }

    @Test func otherFailuresDoNotEndTheSession() async {
        let access = makeAccess()

        await #expect(throws: VaultError.noAccess) {
            try await access.perform { _ -> Int in throw VaultError.noAccess }
        }

        #expect(ended.calls == 0)
    }
}
