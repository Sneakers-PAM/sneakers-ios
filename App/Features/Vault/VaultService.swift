// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// Which server and which signed-in session a request is for.
nonisolated struct ServerContext: Sendable {
    let server: ServerURL
    let session: AuthenticatedSession
}

nonisolated struct FolderContents: Equatable, Sendable {
    let secrets: [SecretSummary]
    let types: [SecretType]
}

/// Reads and acts on the vault through the gateway. The real one calls the network; tests fake it.
nonisolated protocol VaultServicing: Sendable {
    func dashboard(_ context: ServerContext) async throws -> DashboardData
    func folders(_ context: ServerContext) async throws -> [Folder]
    func contents(ofFolder folderID: String, _ context: ServerContext) async throws -> FolderContents
    func secret(id: String, _ context: ServerContext) async throws -> SecretDetail
    func reveal(secretID: String, fieldKey: String, _ context: ServerContext) async throws -> String
    func checkout(secretID: String, _ context: ServerContext) async throws -> Lease
    func checkin(secretID: String, _ context: ServerContext) async throws
}

nonisolated enum VaultError: Error, Equatable, Sendable {
    case noAccess
    case stepUpRequired
    case approvalRequired
    case retired
    case leaseHeld
    case notHolder
    case checkoutNotAllowed
    case notFound
    case sessionEnded
    case unreachable
    case unexpected

    /// What to tell the person. It never repeats the server's own wording.
    var message: String {
        switch self {
        case .noAccess: "You don't have access to that."
        case .stepUpRequired: "Confirm it's you with a code to continue."
        case .approvalRequired: "This secret needs approval before it can be revealed."
        case .retired: "This secret is retired."
        case .leaseHeld: "Someone else has this checked out."
        case .notHolder: "Only the person who checked it out can check it in."
        case .checkoutNotAllowed: "This kind of secret can't be checked out."
        case .notFound: "That secret isn't available."
        case .sessionEnded: "Your session ended. Sign in again."
        case .unreachable: "Couldn't reach the server. Check your connection and try again."
        case .unexpected: "Something went wrong. Try again."
        }
    }

    /// Maps the gateway's GraphQL error code and reason, which are stable, never its message text. A known reason wins,
    /// and anything else falls back to the code.
    init(code: String, reason: String?) {
        if let reason, let known = Self.byReason[reason] {
            self = known
        } else {
            self = Self.byCode[code] ?? .unexpected
        }
    }

    private static let byReason: [String: VaultError] = {
        var table: [String: VaultError] = [:]
        table["CHECKIN_NOT_HOLDER"] = .notHolder
        table["STEP_UP_REQUIRED"] = .stepUpRequired
        table["APPROVAL_REQUIRED"] = .approvalRequired
        table["RETIRED"] = .retired
        table["CHECKOUT_LEASE_HELD"] = .leaseHeld
        table["CHECKOUT_TYPE_DISABLED"] = .checkoutNotAllowed
        return table
    }()

    private static let byCode: [String: VaultError] = {
        var table: [String: VaultError] = [:]
        table["PERMISSION_DENIED"] = .noAccess
        table["NOT_FOUND"] = .notFound
        table["UNAUTHENTICATED"] = .sessionEnded
        table["UNAVAILABLE"] = .unreachable
        table["DEADLINE_EXCEEDED"] = .unreachable
        return table
    }()
}
