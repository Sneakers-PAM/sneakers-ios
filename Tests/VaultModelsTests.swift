// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Sneakers_PAM
import Testing

struct VaultModelsTests {
    private func folder(_ id: String, _ name: String, parent: String? = nil) -> Folder {
        Folder(id: id, name: name, parentId: parent, subtreeSecretCount: nil)
    }

    private func field(_ key: String, sensitive: Bool) -> FieldDefinition {
        FieldDefinition(key: key, label: key.capitalized, kind: "text", sensitive: sensitive, superSensitive: false)
    }

    // MARK: Folder tree

    @Test func rootFoldersHaveNoParentAndAreSortedByName() {
        let platform = folder("2", "Platform")
        let apps = folder("1", "Apps")
        let dev = folder("3", "Dev", parent: "2")
        let tree = FolderTree(folders: [platform, apps, dev])

        #expect(tree.children(of: nil).map(\.name) == ["Apps", "Platform"])
    }

    @Test func aFolderListsItsOwnSubfolders() {
        let platform = folder("1", "Platform")
        let databases = folder("2", "Databases", parent: "1")
        let hosts = folder("3", "Hosts", parent: "1")
        let tree = FolderTree(folders: [platform, databases, hosts])

        #expect(tree.children(of: "1").map(\.name) == ["Databases", "Hosts"])
        #expect(tree.children(of: "2").isEmpty)
    }

    @Test func theTreeNestsFoldersForTheSidebar() {
        let platform = folder("1", "Platform")
        let databases = folder("2", "Databases", parent: "1")
        let apps = folder("3", "Apps")
        let nodes = FolderTree(folders: [platform, databases, apps]).nodes()

        #expect(nodes.map(\.name) == ["Apps", "Platform"])
        #expect(nodes[0].children == nil)
        #expect(nodes[1].children?.map(\.name) == ["Databases"])
    }

    @Test func nestingNeverLoopsOnACycle() {
        let first = folder("1", "A", parent: "2")
        let second = folder("2", "B", parent: "1")

        #expect(FolderTree(folders: [first, second]).nodes().isEmpty)
    }

    @Test func aPathWalksUpToTheRoot() {
        let tree = FolderTree(folders: [folder("1", "Platform"), folder("2", "Databases", parent: "1")])

        #expect(tree.path(of: "2") == "Platform / Databases")
        #expect(tree.path(of: "1") == "Platform")
    }

    @Test func anUnknownFolderHasNoPathAndACycleDoesNotLoopForever() {
        let looping = FolderTree(folders: [folder("1", "A", parent: "2"), folder("2", "B", parent: "1")])

        #expect(looping.path(of: "9") == nil)
        #expect(looping.path(of: "1") != nil)
    }

    // MARK: Health

    @Test func theHeartbeatResultMapsToAHealthStatus() {
        #expect(HealthStatus(heartbeatResult: "ok", hasTarget: true) == .verified)
        #expect(HealthStatus(heartbeatResult: "failed", hasTarget: true) == .drift)
        #expect(HealthStatus(heartbeatResult: "unreachable", hasTarget: true) == .unreachable)
        #expect(HealthStatus(heartbeatResult: "unknown", hasTarget: true) == .unknown)
        #expect(HealthStatus(heartbeatResult: "hostKeyMismatch", hasTarget: true) == .unknown)
    }

    @Test func aSecretWithNoTargetHasNoHealthToShow() {
        #expect(HealthStatus(heartbeatResult: nil, hasTarget: false) == .none)
        #expect(HealthStatus(heartbeatResult: "unknown", hasTarget: false) == .none)
    }

    @Test func eachHealthStatusHasALabel() {
        #expect(HealthStatus.verified.label == "Verified")
        #expect(HealthStatus.drift.label == "Drift")
        #expect(HealthStatus.unreachable.label == "Unreachable")
        #expect(HealthStatus.unknown.label == "Unknown")
        #expect(HealthStatus.none.label == "No target")
    }

    // MARK: Dates

    @Test func theGatewayDatesParseInTheirUsualForms() {
        #expect(GatewayDate.parse("2026-10-28T12:00:00Z") == Date(timeIntervalSince1970: 1_793_188_800))
        #expect(GatewayDate.parse("2026-10-28T12:00:00.250Z") != nil)
        #expect(GatewayDate.parse("1793188800") == Date(timeIntervalSince1970: 1_793_188_800))
        #expect(GatewayDate.parse("") == nil)
        #expect(GatewayDate.parse("soon") == nil)
    }

    // MARK: Lease countdown

    @Test func theCountdownShowsHoursMinutesAndSeconds() {
        #expect(LeaseCountdown.text(remaining: 7152) == "1:59:12")
        #expect(LeaseCountdown.text(remaining: 59 * 60 + 12) == "59:12")
        #expect(LeaseCountdown.text(remaining: 9) == "0:09")
    }

    @Test func anExpiredLeaseSaysExpired() {
        #expect(LeaseCountdown.text(remaining: 0) == "Expired")
        #expect(LeaseCountdown.text(remaining: -30) == "Expired")
    }

    @Test func theRemainingTimeIsMeasuredFromNow() {
        let now = Date(timeIntervalSince1970: 1000)
        #expect(LeaseCountdown.remaining(until: Date(timeIntervalSince1970: 1090), now: now) == 90)
        #expect(LeaseCountdown.remaining(until: Date(timeIntervalSince1970: 900), now: now) == 0)
    }

    // MARK: Secret types

    @Test func theMainSecretValueIsTheFirstSensitiveField() {
        let username = field("username", sensitive: false)
        let password = field("password", sensitive: true)
        let token = field("token", sensitive: true)
        let fields = [username, password, token]
        let type = SecretType(id: "t", name: "Database", checkout: true, fields: fields)

        #expect(type.primarySensitiveFieldKey == "password")
    }

    @Test func aTypeWithNoSensitiveFieldHasNoMainValue() {
        let type = SecretType(id: "t", name: "Note", checkout: false, fields: [field("body", sensitive: false)])

        #expect(type.primarySensitiveFieldKey == nil)
    }

    @Test func aFolderSaysHowManySecretsItHoldsIncludingItsSubfolders() {
        func text(_ count: Int?) -> String {
            Folder(id: "1", name: "F", parentId: nil, subtreeSecretCount: count).secretCountText
        }
        #expect(text(nil) == "")
        #expect(text(0) == "Empty")
        #expect(text(1) == "1 secret")
        #expect(text(4) == "4 secrets")
    }

    @Test func eachFieldKindTheGatewayNamesIsKnownAndAnythingElseIsText() {
        #expect(FieldKind(gateway: "multiline") == .multiline)
        #expect(FieldKind(gateway: "password") == .password)
        #expect(FieldKind(gateway: "boolean") == .boolean)
        #expect(FieldKind(gateway: "select") == .select)
        #expect(FieldKind(gateway: "file") == .file)
        #expect(FieldKind(gateway: "sensitive") == .sensitive)
        #expect(FieldKind(gateway: "text") == .text)
        #expect(FieldKind(gateway: nil) == .text)
        #expect(FieldKind(gateway: "something new") == .text)
    }

    @Test func aFieldKnowsItsKindOptionsAndLimits() throws {
        let json = #"{"key":"mode","label":"Mode","kind":"select","options":["a","b"],"required":true,"maxLength":12}"#
        let definition = try JSONDecoder().decode(FieldDefinition.self, from: Data(json.utf8))
        #expect(definition.fieldKind == .select)
        #expect(definition.options == ["a", "b"])
        #expect(definition.isRequired)
        #expect(definition.maxLength == 12)
    }

    @Test func passwordAndSensitiveFieldsAreHiddenByDefault() {
        func hidden(_ kind: String, sensitive: Bool? = nil) -> Bool {
            FieldDefinition(key: "k", label: "K", kind: kind, sensitive: sensitive, superSensitive: nil).isSensitive
        }
        #expect(hidden("password"))
        #expect(hidden("sensitive"))
        #expect(hidden("text", sensitive: true))
        #expect(!hidden("text"))
    }

    @Test func accessReadsWhatThePersonMayDoAndDefaultsToNothing() throws {
        let json = #"{"read":true,"reveal":true,"manage":false,"approve":false,"informed":true,"manageRuleset":false}"#
        let access = try JSONDecoder().decode(Access.self, from: Data(json.utf8))
        #expect(access.read && access.reveal && access.informed)
        #expect(!access.manage && !access.approve && !access.manageRuleset)
        #expect(!Access.none.read && !Access.none.manage)
    }

    private func version(
        _ number: Int,
        changed: [String] = [],
        label: String? = nil,
        at created: String = "2026-10-28T12:00:00Z"
    ) -> SecretVersion {
        SecretVersion(
            versionNo: number, createdBy: "u1", createdByName: "Alice", createdAt: created,
            active: number == 3, fieldKeys: ["username", "password"], changedFieldKeys: changed, changeLabel: label
        )
    }

    @Test func aVersionSaysWhichFieldsChangedUsingTheirLabels() {
        let labels = ["username": "Username", "password": "Password"]

        #expect(version(2, changed: ["password"]).summary(labels: labels) == "Changed: Password")
        #expect(version(2, changed: ["username", "password"]).summary(labels: labels) == "Changed: Username, Password")
        #expect(version(2, changed: ["gone"]).summary(labels: labels) == "Changed: gone")
    }

    @Test func aVersionWithNoChangedValueSaysSo() {
        #expect(version(2).summary(labels: [:]) == "No value changed")
    }

    @Test func theFirstVersionIsTheCreation() {
        #expect(version(1, changed: ["username", "password"]).summary(labels: [:]) == "Created")
    }

    @Test func aTypeChangeUsesTheServersOwnDescription() {
        #expect(version(2, changed: ["x"], label: "Type changed: A to B")
            .summary(labels: [:]) == "Type changed: A to B")
    }

    @Test func versionsAreListedNewestFirst() {
        let sorted = [version(1), version(3), version(2)].sortedNewestFirst()

        #expect(sorted.map(\.versionNo) == [3, 2, 1])
    }

    @Test func aHostKeyProblemIsExplainedAndAnythingElseHasNoNote() {
        func note(_ result: String?) -> String? {
            SecretSummary(
                id: "1", name: "n", folderId: nil, typeId: nil, targetId: "t", lastHeartbeatResult: result,
                retired: false, canRead: true, viewCount: nil, lastAccessedAt: nil
            ).heartbeatNote
        }
        #expect(note("hostKeyNotPinned") != nil)
        #expect(note("hostKeyMismatch") != nil)
        #expect(note("ok") == nil)
        #expect(note("failed") == nil)
        #expect(note(nil) == nil)
    }

    @Test func aRotationStateHasALabelAndAnUnknownOneIsUnknown() {
        #expect(RotationState(gateway: "ok") == .succeeded)
        #expect(RotationState(gateway: "rotating") == .rotating)
        #expect(RotationState(gateway: "failed") == .failed)
        #expect(RotationState(gateway: "degraded") == .degraded)
        #expect(RotationState(gateway: nil) == .unknown)
        #expect(RotationState(gateway: "??") == .unknown)
        #expect(RotationState.succeeded.label == "Rotated")
        #expect(RotationState.degraded.label == "Degraded")
    }

    @Test func aTypeSaysWhetherItCanBeRotatedAndCheckedForHealth() throws {
        let json = #"{"id":"t1","name":"T","checkout":true,"heartbeat":true,"rotation":false,"fields":[]}"#
        let type = try JSONDecoder().decode(SecretType.self, from: Data(json.utf8))

        #expect(type.supportsHeartbeat)
        #expect(!type.supportsRotation)
        #expect(!SecretType(id: "t", name: "T", checkout: nil, fields: nil).supportsHeartbeat)
    }
}
