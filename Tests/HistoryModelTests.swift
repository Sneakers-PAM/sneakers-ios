// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Sneakers_PAM
import Testing

@MainActor
struct HistoryModelTests {
    private let vault = FakeVaultService()

    private func makeAccess() -> VaultAccess {
        VaultAccess(service: vault, context: { .fixture }, onSessionEnded: {})
    }

    private func version(_ number: Int) -> SecretVersion {
        SecretVersion(
            versionNo: number, createdBy: "u1", createdByName: "Alice", createdAt: "2026-10-28T12:00:00Z",
            active: number == 2, fieldKeys: ["password"], changedFieldKeys: ["password"], changeLabel: nil
        )
    }

    @Test func startsLoading() {
        #expect(HistoryModel(secretID: "s1").phase == .loading)
    }

    @Test func versionsLoadNewestFirst() async {
        vault.versionsResult = .success([version(1), version(2)])
        let model = HistoryModel(secretID: "s1")

        await model.load(makeAccess())

        #expect(model.phase == .loaded([version(2), version(1)]))
    }

    @Test func aHistoryThatCannotLoadSaysWhy() async {
        vault.versionsResult = .failure(.noAccess)
        let model = HistoryModel(secretID: "s1")

        await model.load(makeAccess())

        #expect(model.phase == .failed(VaultError.noAccess.message))
    }

    @Test func theActiveVersionCannotBeRestored() {
        let model = HistoryModel(secretID: "s1")

        #expect(!model.canRestore(version(2)))
        #expect(model.canRestore(version(1)))
    }
}
