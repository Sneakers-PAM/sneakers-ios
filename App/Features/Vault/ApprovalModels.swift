// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// A reveal the vault is holding until someone approves it. The value is read with `redeem`, once, after approval.
nonisolated struct HeldReveal: Equatable, Sendable {
    let id: String
    let state: String
    /// Nobody else can decide it, so the person who asked confirms it with a second factor.
    let confirm: Bool
    let expiresAt: Date
    let runID: String?

    var isApproved: Bool {
        state == "APPROVED"
    }
}

/// What an approval request asks for.
nonisolated enum ApprovalKind: Equatable, Sendable {
    case secretAccess, folderMove, secretMove

    init(gateway name: String) {
        switch name {
        case "folder_move": self = .folderMove
        case "secret_move": self = .secretMove
        default: self = .secretAccess
        }
    }

    var isMove: Bool {
        self != .secretAccess
    }
}

nonisolated enum ApprovalStatus: Equatable, Sendable {
    case pending, approved, denied

    init(gateway name: String) {
        switch name {
        case "approved": self = .approved
        case "denied": self = .denied
        default: self = .pending
        }
    }

    var label: String {
        switch self {
        case .pending: "Pending"
        case .approved: "Approved"
        case .denied: "Denied"
        }
    }
}

/// How long an approval of access lasts: eight hours unless the approver picks, and never more than a day.
nonisolated enum GrantHours {
    static let standard = 8
    static let longest = 24
    static let choices = [1, 4, 8, 24]
}

nonisolated struct ApprovalComment: Equatable, Identifiable, Sendable {
    let id: String
    let authorID: String
    let authorName: String
    let body: String
    let createdAt: Date?
}

nonisolated struct ApprovalRequest: Equatable, Identifiable, Sendable {
    let id: String
    let kind: ApprovalKind
    let secretID: String
    let folderName: String?
    let destParentName: String?
    let requestedByUserID: String
    let requestedAt: Date?
    let reason: String?
    let status: ApprovalStatus
    let resolvedAt: Date?
    let resolvedByUserID: String?
    let resolvedByName: String?
    let comments: [ApprovalComment]
}

/// Everything the requests screens need, fetched together: the requests, the names of their secrets, which of those I
/// may approve, and the people involved.
nonisolated struct RequestsOverview: Equatable, Sendable {
    var requests: [ApprovalRequest]
    var secretNames: [String: String]
    var secretsIMayApprove: Set<String>
    var people: [String: String]
}

/// One request as a screen shows it, named and checked against the person looking.
nonisolated struct RequestRow: Equatable, Identifiable, Sendable {
    let request: ApprovalRequest
    let resource: String
    let requestedBy: String
    let mine: Bool
    let canDecide: Bool

    var id: String {
        request.id
    }

    var title: String {
        switch request.kind {
        case .secretAccess: "Access to \(resource)"
        case .secretMove: "Move \(resource) to \(request.destParentName ?? "a personal folder")"
        case .folderMove: "Move \(request.folderName ?? "a folder") to \(request.destParentName ?? "a personal folder")"
        }
    }
}

/// The requests that concern me, in the three groups the screens show: waiting for my decision, mine and still open,
/// and decided. A move needs a site admin, so only an admin can decide one.
nonisolated struct RequestBoard: Equatable, Sendable {
    let awaiting: [RequestRow]
    let open: [RequestRow]
    let history: [RequestRow]

    init(_ overview: RequestsOverview, for userID: String, isAdmin: Bool = false) {
        func mayDecide(_ request: ApprovalRequest) -> Bool {
            request.requestedByUserID != userID
                && (request.kind.isMove ? isAdmin : overview.secretsIMayApprove.contains(request.secretID))
        }
        func row(_ request: ApprovalRequest) -> RequestRow {
            RequestRow(
                request: request,
                resource: overview.secretNames[request.secretID] ?? request.folderName ?? "a secret",
                requestedBy: overview.people[request.requestedByUserID] ?? "Someone",
                mine: request.requestedByUserID == userID,
                canDecide: request.status == .pending && mayDecide(request)
            )
        }
        let involved = overview.requests
            .filter { $0.requestedByUserID == userID || $0.resolvedByUserID == userID || mayDecide($0) }
            .sorted { ($0.requestedAt ?? .distantPast) > ($1.requestedAt ?? .distantPast) }
            .map(row)
        awaiting = involved.filter(\.canDecide)
        open = involved.filter { $0.mine && $0.request.status == .pending }
        history = involved.filter { $0.request.status != .pending }
    }
}
