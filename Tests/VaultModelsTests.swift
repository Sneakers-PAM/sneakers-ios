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
}
