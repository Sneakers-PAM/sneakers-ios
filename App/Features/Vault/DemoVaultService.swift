// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

#if DEBUG
    import Foundation
    import os

    /// A vault of made-up data for the UI tests. Debug builds only, and only when a test launch argument asks for it.
    /// Its first reveal asks for a fresh second factor, so the step-up flow can be driven end to end.
    final nonisolated class DemoVaultService: VaultServicing, @unchecked Sendable {
        private struct State {
            var revealAttempts = 0
            var lease: Lease?
            var retired = false
            var rotatedAt: Date?
            var rotationOptOut = false
            var heartbeatOptOut = false
            var addedFolders: [Folder] = []
            var renamedFolders: [String: String] = [:]
            var addedSecrets: [(name: String, folderID: String)] = []
            var editedName: String?
            var editedFields: [String: String] = [:]
        }

        private let state = OSAllocatedUnfairLock(initialState: State())

        static let revealedValue = "demo-value-123"

        func dashboard(_: ServerContext) async throws -> DashboardData {
            let stats = SecretStats(total: 148, expiringSoon: 12, expired: 2, drift: 3)
            let top = [summary("s1", "DB admin", views: 42), summary("s2", "Deploy key", views: 17)]
            let held = Lease(
                id: "l9",
                secretId: "s9",
                userId: "ui-test",
                issuedAt: iso(0),
                expiresAt: iso(7140),
                returned: false
            )
            return DashboardData(
                stats: stats,
                topSecrets: top,
                leases: [LeaseWithName(lease: held, secretName: "Acme VPN")]
            )
        }

        func folders(_: ServerContext) async throws -> [Folder] {
            let platform = Folder(id: "1", name: "Platform", parentId: nil, subtreeSecretCount: 2)
            let databases = Folder(id: "2", name: "Databases", parentId: "1", subtreeSecretCount: 2)
            let apps = Folder(id: "3", name: "Apps", parentId: nil, subtreeSecretCount: 1)
            let extra = state.withLock { $0.addedFolders }
            let renames = state.withLock { $0.renamedFolders }
            return ([platform, databases, apps] + extra).map { folder in
                guard let name = renames[folder.id] else { return folder }
                return Folder(
                    id: folder.id, name: name, parentId: folder.parentId,
                    subtreeSecretCount: folder.subtreeSecretCount, canManage: true
                )
            }
        }

        func contents(ofFolder folderID: String, _: ServerContext) async throws -> FolderContents {
            let added = state.withLock { $0.addedSecrets }.filter { $0.folderID == folderID }
                .map { summary("added-\($0.name)", $0.name, views: 0) }
            switch folderID {
            case "3":
                let vendor = SecretSummary(
                    id: "s8", name: "Vendor key", folderId: "3", typeId: "t1", targetId: nil,
                    lastHeartbeatResult: nil, retired: false, canRead: false, viewCount: 0, lastAccessedAt: nil
                )
                return FolderContents(
                    secrets: [summary("s1", "DB admin", views: 42), vendor] + added,
                    types: [Self.databaseType]
                )
            case "2":
                return FolderContents(
                    secrets: [summary("s2", "Deploy key", views: 17)] + added, types: [Self.databaseType]
                )
            default:
                return FolderContents(secrets: added, types: [Self.databaseType])
            }
        }

        func secret(id: String, _: ServerContext) async throws -> SecretDetail {
            let (held, edited) = state.withLock { ($0.lease, $0) }
            let name = edited.editedName ?? (id == "s2" ? "Deploy key" : "DB admin")
            if id == "s8" {
                return SecretDetail(
                    summary: lockedSummary, type: Self.databaseType, values: [:], lease: nil,
                    folderPath: "Apps", expiresAt: nil, verifiedAt: nil, nextRotationAt: nil
                )
            }
            let lifecycle = SecretLifecycle(
                rotation: edited.rotatedAt == nil ? nil : .succeeded,
                rotatedAt: edited.rotatedAt,
                rotationOptOut: edited.rotationOptOut,
                heartbeatOptOut: edited.heartbeatOptOut
            )
            return SecretDetail(
                summary: summary(id, name, views: 3, retired: edited.retired),
                type: Self.databaseType,
                values: ["username": "app_admin"]
                    .merging(edited.editedFields.filter { $0.key == "username" }) { _, new in new },
                lease: held,
                folderPath: "Platform / Databases",
                expiresAt: nil,
                verifiedAt: Date().addingTimeInterval(-300),
                nextRotationAt: Date().addingTimeInterval(86400 * 7),
                lifecycle: lifecycle
            )
        }

        func reveal(secretID _: String, fieldKey _: String, _: ServerContext) async throws -> String {
            let attempt = state.withLock { state -> Int in
                state.revealAttempts += 1
                return state.revealAttempts
            }
            if attempt == 1 {
                throw VaultError.stepUpRequired
            }
            return Self.revealedValue
        }

        func checkout(secretID: String, _: ServerContext) async throws -> Lease {
            let taken = Lease(
                id: "l1",
                secretId: secretID,
                userId: "ui-test",
                issuedAt: iso(0),
                expiresAt: iso(7200),
                returned: false
            )
            state.withLock { $0.lease = taken }
            return taken
        }

        func access(forFolder _: String, _: ServerContext) async throws -> Access {
            Access(read: true, reveal: true, manage: true, approve: false, informed: false, manageRuleset: false)
        }

        func access(forSecret secretID: String, _: ServerContext) async throws -> Access {
            if secretID == "s8" {
                return .none
            }
            return Access(read: true, reveal: true, manage: true, approve: false, informed: false, manageRuleset: false)
        }

        func rotate(secretID _: String, _: ServerContext) async throws {
            state.withLock { $0.rotatedAt = Date() }
        }

        func retire(secretID _: String, _: ServerContext) async throws {
            state.withLock { $0.retired = true }
        }

        func reinstate(secretID _: String, _: ServerContext) async throws {
            state.withLock { $0.retired = false }
        }

        func setAutomation(secretID _: String, _ setting: AutomationSetting, _: ServerContext) async throws {
            state.withLock {
                $0.rotationOptOut = setting.disableRotation
                $0.heartbeatOptOut = setting.disableHeartbeat
            }
        }

        func createFolder(parentID: String?, name: String, _: ServerContext) async throws -> Folder {
            let id = "new-\(name)"
            state.withLock { $0.addedFolders.append(Folder(
                id: id,
                name: name,
                parentId: parentID,
                subtreeSecretCount: 0
            )) }
            return Folder(id: id, name: name, parentId: parentID, subtreeSecretCount: 0)
        }

        func renameFolder(id: String, name: String, _: ServerContext) async throws {
            state.withLock { $0.renamedFolders[id] = name }
        }

        func moveFolder(id _: String, to _: String?, _: ServerContext) async throws {}

        func moveSecret(id _: String, to _: String, _: ServerContext) async throws {}

        func requestMove(_: MoveRequest, _: ServerContext) async throws {}

        func secretTypes(_: ServerContext) async throws -> [SecretType] {
            [Self.databaseType]
        }

        func createSecret(_ secret: NewSecret, _: ServerContext) async throws -> String {
            state.withLock { $0.addedSecrets.append((secret.name, secret.folderID)) }
            return "s-new"
        }

        func versions(secretID _: String, _: ServerContext) async throws -> [SecretVersion] {
            let now = ISO8601DateFormatter().string(from: Date())
            let keys = ["username", "password"]
            let current = SecretVersion(
                versionNo: 2, createdBy: "u1", createdByName: "Alice", createdAt: now, active: true,
                fieldKeys: keys, changedFieldKeys: ["password"], changeLabel: nil
            )
            let first = SecretVersion(
                versionNo: 1, createdBy: "u1", createdByName: "Alice", createdAt: now, active: false,
                fieldKeys: keys, changedFieldKeys: keys, changeLabel: nil
            )
            return [current, first]
        }

        func revealVersion(_: RevealKey, _: ServerContext) async throws -> String {
            "old-demo-value"
        }

        func restore(secretID _: String, versionNo _: Int, _: ServerContext) async throws {}

        func update(secretID _: String, _ change: SecretChange, _: ServerContext) async throws {
            state.withLock { state in
                if let name = change.name {
                    state.editedName = name
                }
                state.editedFields.merge(change.fields) { _, new in new }
            }
        }

        func checkin(secretID _: String, _: ServerContext) async throws {
            state.withLock { $0.lease = nil }
        }

        private let lockedSummary = SecretSummary(
            id: "s8", name: "Vendor key", folderId: "3", typeId: "t1", targetId: nil,
            lastHeartbeatResult: nil, retired: false, canRead: false, viewCount: 0, lastAccessedAt: nil
        )

        private func summary(_ id: String, _ name: String, views: Int, retired: Bool = false) -> SecretSummary {
            SecretSummary(
                id: id, name: name, folderId: "2", typeId: "t1", targetId: "tg1", lastHeartbeatResult: "ok",
                retired: retired, canRead: true, viewCount: views, lastAccessedAt: nil
            )
        }

        private func iso(_ seconds: TimeInterval) -> String {
            ISO8601DateFormatter().string(from: Date().addingTimeInterval(seconds))
        }

        private static let databaseType: SecretType = {
            let username = FieldDefinition(
                key: "username",
                label: "Username",
                kind: "text",
                sensitive: false,
                superSensitive: false
            )
            let password = FieldDefinition(
                key: "password",
                label: "Password",
                kind: "text",
                sensitive: true,
                superSensitive: false
            )
            return SecretType(
                id: "t1", name: "Database account", checkout: true, fields: [username, password],
                heartbeat: true, rotation: true
            )
        }()
    }
#endif
