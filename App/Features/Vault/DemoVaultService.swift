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
            return [platform, databases, apps]
        }

        func contents(ofFolder folderID: String, _: ServerContext) async throws -> FolderContents {
            switch folderID {
            case "3":
                let vendor = SecretSummary(
                    id: "s8", name: "Vendor key", folderId: "3", typeId: "t1", targetId: nil,
                    lastHeartbeatResult: nil, retired: false, canRead: false, viewCount: 0, lastAccessedAt: nil
                )
                return FolderContents(
                    secrets: [summary("s1", "DB admin", views: 42), vendor],
                    types: [Self.databaseType]
                )
            case "2":
                return FolderContents(secrets: [summary("s2", "Deploy key", views: 17)], types: [Self.databaseType])
            default:
                return FolderContents(secrets: [], types: [])
            }
        }

        func secret(id: String, _: ServerContext) async throws -> SecretDetail {
            let name = id == "s2" ? "Deploy key" : "DB admin"
            let held = state.withLock { $0.lease }
            if id == "s8" {
                return SecretDetail(
                    summary: lockedSummary, type: Self.databaseType, values: [:], lease: nil,
                    folderPath: "Apps", expiresAt: nil, verifiedAt: nil, nextRotationAt: nil
                )
            }
            return SecretDetail(
                summary: summary(id, name, views: 3),
                type: Self.databaseType,
                values: ["username": "app_admin"],
                lease: held,
                folderPath: "Platform / Databases",
                expiresAt: nil,
                verifiedAt: nil,
                nextRotationAt: nil
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

        func checkin(secretID _: String, _: ServerContext) async throws {
            state.withLock { $0.lease = nil }
        }

        private let lockedSummary = SecretSummary(
            id: "s8", name: "Vendor key", folderId: "3", typeId: "t1", targetId: nil,
            lastHeartbeatResult: nil, retired: false, canRead: false, viewCount: 0, lastAccessedAt: nil
        )

        private func summary(_ id: String, _ name: String, views: Int) -> SecretSummary {
            SecretSummary(
                id: id, name: name, folderId: "2", typeId: "t1", targetId: "tg1", lastHeartbeatResult: "ok",
                retired: false, canRead: true, viewCount: views, lastAccessedAt: nil
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
            return SecretType(id: "t1", name: "Database account", checkout: true, fields: [username, password])
        }()
    }
#endif
