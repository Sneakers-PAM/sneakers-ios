// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Sneakers_PAM
import Testing

@MainActor
struct VaultRefusalTests {
    private let vault = FakeVaultService()
    private let auth = FakeAuthenticator()

    private func makeAccess() -> VaultAccess {
        VaultAccess(service: vault, context: { .fixture }, onSessionEnded: {})
    }

    private struct Mapping {
        let code: String
        let reason: String
        let expected: VaultError

        init(_ code: String, _ reason: String, _ expected: VaultError) {
            self.code = code
            self.reason = reason
            self.expected = expected
        }
    }

    @Test func theVaultsOwnReasonsMapToTheirMeanings() {
        var table: [Mapping] = []
        table.append(Mapping("FAILED_PRECONDITION", "ROTATION_IN_PROGRESS", .rotationInProgress))
        table.append(Mapping("FAILED_PRECONDITION", "ROTATION_NOT_SUPPORTED", .rotationNotSupported))
        table.append(Mapping("FAILED_PRECONDITION", "ROTATION_OPTED_OUT", .rotationOptedOut))
        table.append(Mapping("PERMISSION_DENIED", "SELF_APPROVAL", .selfApproval))
        table.append(Mapping("PERMISSION_DENIED", "NOT_APPROVER", .notApprover))
        table.append(Mapping("FAILED_PRECONDITION", "NO_APPROVER", .noApprover))
        table.append(Mapping("FAILED_PRECONDITION", "REQUEST_NOT_PENDING", .alreadyDecided))
        table.append(Mapping("PERMISSION_DENIED", "NOT_SITE_ADMIN", .notSiteAdmin))
        table.append(Mapping("PERMISSION_DENIED", "NOT_FOLDER_OWNER", .notFolderOwner))
        for item in table {
            #expect(VaultError(code: item.code, reason: item.reason) == item.expected, "\(item.reason)")
        }
    }

    @Test func everyNewRefusalHasAPlainMessageThatNeverEchoesServerText() {
        var all: [VaultError] = [.rotationInProgress, .rotationNotSupported, .rotationOptedOut, .selfApproval]
        all += [.notApprover, .noApprover, .alreadyDecided, .notSiteAdmin, .notFolderOwner, .checkedOut]
        for failure in all {
            #expect(!failure.message.isEmpty)
            #expect(!failure.message.lowercased().contains("rpc"))
        }
    }

    @Test func aLeaseHeldRefusalOnAChangeSaysTheSecretIsCheckedOut() {
        #expect(VaultError.leaseHeld.forAChange == .checkedOut)
        #expect(VaultError.noAccess.forAChange == .noAccess)
        #expect(VaultError.checkedOut.message.contains("checked in"))
    }

    @Test func rotatingASecretThatIsCheckedOutSaysSo() async {
        vault.detailResult = .success(SecretDetail(
            summary: .fixture(), type: SecretType(
                id: "t1", name: "T", checkout: true, fields: [], heartbeat: true, rotation: true
            ),
            values: [:], lease: nil, folderPath: nil, expiresAt: nil, verifiedAt: nil, nextRotationAt: nil
        ))
        vault.secretAccessResult = .success(.fixtureFull)
        let model = SecretDetailModel(secretID: "s1")
        await model.load(makeAccess())
        vault.lifecycleResult = .failure(.leaseHeld)

        await model.rotateNow(makeAccess())

        #expect(model.message == VaultError.checkedOut.message)
    }

    @Test func restoringAVersionOfASecretThatIsCheckedOutSaysSo() async {
        vault.restoreResults = [.failure(.leaseHeld)]
        let coordinator = RevealCoordinator(
            access: makeAccess(), auth: FakeAuthService(), clipboard: FakeClipboard()
        )

        await coordinator.restore(secretID: "s1", versionNo: 2)

        #expect(coordinator.notice == VaultError.checkedOut.message)
    }

    @Test func aRotationAlreadyRunningIsSaidPlainlyWhenRestoring() async {
        vault.restoreResults = [.failure(.rotationInProgress)]
        let coordinator = RevealCoordinator(
            access: makeAccess(), auth: FakeAuthService(), clipboard: FakeClipboard()
        )

        await coordinator.restore(secretID: "s1", versionNo: 2)

        #expect(coordinator.notice == VaultError.rotationInProgress.message)
    }

    @Test func savingAnEditToASecretThatIsCheckedOutSaysSo() async {
        vault.updateResult = .failure(.leaseHeld)
        let field = FieldDefinition(
            key: "username",
            label: "Username",
            kind: "text",
            sensitive: false,
            superSensitive: false
        )
        let edit = EditSecretModel(secretID: "s1", name: "DB admin", fields: [field], values: ["username": "a"])
        edit.set("b", for: "username")

        await edit.save(makeAccess())

        #expect(edit.message == VaultError.checkedOut.message)
    }
}
