// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Sneakers_PAM
import Testing

@MainActor
struct SecretLifecycleModelTests {
    private let vault = FakeVaultService()

    private func makeAccess() -> VaultAccess {
        VaultAccess(service: vault, context: { .fixture }, onSessionEnded: {})
    }

    // MARK: Lifecycle

    private func lifecycleDetail(
        retired: Bool = false,
        lifecycle: SecretLifecycle = SecretLifecycle(),
        type: SecretType? = nil
    ) -> SecretDetail {
        var summary = SecretSummary.fixture(id: "s1", name: "DB admin")
        summary = SecretSummary(
            id: summary.id, name: summary.name, folderId: summary.folderId, typeId: summary.typeId,
            targetId: summary.targetId, lastHeartbeatResult: summary.lastHeartbeatResult, retired: retired,
            canRead: true, viewCount: 1, lastAccessedAt: nil
        )
        let capable = SecretType(id: "t1", name: "T", checkout: true, fields: [], heartbeat: true, rotation: true)
        return SecretDetail(
            summary: summary, type: type ?? capable, values: [:], lease: nil, folderPath: nil,
            expiresAt: nil, verifiedAt: nil, nextRotationAt: nil, lifecycle: lifecycle
        )
    }

    private func loaded(_ detail: SecretDetail, access: Access = .fixtureFull) async -> SecretDetailModel {
        vault.detailResult = .success(detail)
        vault.secretAccessResult = .success(access)
        let model = SecretDetailModel(secretID: "s1")
        await model.load(makeAccess())
        return model
    }

    @Test func aManagerCanRotateARotatableSecretThatIsNotOptedOut() async {
        let model = await loaded(lifecycleDetail())

        #expect(model.canRotate)
        #expect(model.canRetire)
        #expect(!model.canReinstate)
    }

    @Test func someoneWhoOnlyReadsCannotRotateRetireOrSwitchAutomation() async {
        let model = await loaded(lifecycleDetail(), access: .fixtureReadOnly)

        #expect(!model.canRotate)
        #expect(!model.canRetire)
        #expect(!model.canToggleHeartbeat)
        #expect(!model.canToggleRotation)
    }

    @Test func aRotationOptOutStopsRotatingNowButCanBeSwitchedBack() async {
        let model = await loaded(lifecycleDetail(lifecycle: SecretLifecycle(rotationOptOut: true)))

        #expect(!model.canRotate)
        #expect(model.canToggleRotation)
    }

    @Test func aRetiredSecretCanOnlyBeReinstated() async {
        let model = await loaded(lifecycleDetail(retired: true))

        #expect(model.canReinstate)
        #expect(!model.canRetire)
        #expect(!model.canRotate)
    }

    @Test func theHeartbeatCannotBeSwitchedWhileSomethingBlocksIt() async {
        let blocked = SecretLifecycle(heartbeatBlockedReason: "no target")
        let model = await loaded(lifecycleDetail(lifecycle: blocked))

        #expect(!model.canToggleHeartbeat)
    }

    @Test func aTypeWithoutRotationOffersNoRotation() async {
        let plain = SecretType(id: "t1", name: "T", checkout: true, fields: [], heartbeat: false, rotation: false)
        let model = await loaded(lifecycleDetail(type: plain))

        #expect(!model.canRotate)
        #expect(!model.canToggleRotation)
        #expect(!model.canToggleHeartbeat)
    }

    @Test func rotatingNowAsksTheServerAndReloads() async {
        let model = await loaded(lifecycleDetail())

        await model.rotateNow(makeAccess())

        #expect(vault.rotations == ["s1"])
        #expect(model.message == nil)
    }

    @Test func aRefusedRotationSaysWhy() async {
        vault.lifecycleResult = .failure(.noAccess)
        let model = await loaded(lifecycleDetail())

        await model.rotateNow(makeAccess())

        #expect(model.message == VaultError.noAccess.message)
    }

    @Test func retiringAndReinstatingAskTheServer() async {
        let model = await loaded(lifecycleDetail())

        await model.retire(makeAccess())
        await model.reinstate(makeAccess())

        #expect(vault.retirements == ["s1"])
        #expect(vault.reinstatements == ["s1"])
    }

    @Test func switchingTheHeartbeatOffKeepsTheRotationSettingAsItWas() async {
        let model = await loaded(lifecycleDetail(lifecycle: SecretLifecycle(rotationOptOut: true)))

        await model.setHeartbeat(on: false, makeAccess())

        #expect(vault.automations.first?.setting == AutomationSetting(disableRotation: true, disableHeartbeat: true))
    }

    @Test func switchingTheRotationOnClearsItsOptOut() async {
        let model = await loaded(lifecycleDetail(lifecycle: SecretLifecycle(rotationOptOut: true)))

        await model.setRotation(on: true, makeAccess())

        #expect(vault.automations.first?.setting == AutomationSetting(disableRotation: false, disableHeartbeat: false))
    }
}
