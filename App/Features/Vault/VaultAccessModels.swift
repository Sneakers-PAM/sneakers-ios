// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// One saved version of a secret. It names who changed what and when, and never carries a value.
nonisolated struct SecretVersion: Decodable, Equatable, Identifiable, Sendable {
    let versionNo: Int
    let createdBy: String
    let createdByName: String
    let createdAt: String
    let active: Bool
    let fieldKeys: [String]
    let changedFieldKeys: [String]
    let changeLabel: String?

    var id: Int {
        versionNo
    }

    var createdAtDate: Date? {
        GatewayDate.parse(createdAt)
    }

    /// A line for the history list. The server's own description of a type change wins, then the changed fields by
    /// their labels.
    func summary(labels: [String: String]) -> String {
        if let changeLabel, !changeLabel.isEmpty {
            return changeLabel
        }
        if versionNo == 1 {
            return "Created"
        }
        if changedFieldKeys.isEmpty {
            return "No value changed"
        }
        return "Changed: " + changedFieldKeys.map { labels[$0] ?? $0 }.joined(separator: ", ")
    }
}

extension [SecretVersion] {
    nonisolated func sortedNewestFirst() -> [SecretVersion] {
        sorted { $0.versionNo > $1.versionNo }
    }
}

/// What the signed-in person may do in a folder or on a secret, as the gateway works it out.
nonisolated struct Access: Decodable, Equatable, Sendable {
    let read: Bool
    let reveal: Bool
    let manage: Bool
    let approve: Bool
    let informed: Bool
    let manageRuleset: Bool

    static let none = Access(
        read: false, reveal: false, manage: false, approve: false, informed: false, manageRuleset: false
    )
}

/// How the last rotation of a secret went.
nonisolated enum RotationState: Equatable, Sendable {
    case succeeded, failed, degraded, rotating, unknown

    init(gateway name: String?) {
        switch name {
        case "ok": self = .succeeded
        case "failed": self = .failed
        case "degraded": self = .degraded
        case "rotating": self = .rotating
        default: self = .unknown
        }
    }

    var label: String {
        switch self {
        case .succeeded: "Rotated"
        case .failed: "Failed"
        case .degraded: "Degraded"
        case .rotating: "Rotating"
        case .unknown: "Not rotated yet"
        }
    }
}

/// Whether the automatic rotation and the heartbeat check are switched off for one secret.
nonisolated struct AutomationSetting: Equatable, Sendable {
    var disableRotation: Bool
    var disableHeartbeat: Bool
}

/// The automatic checking and rotating of a secret, and whether someone turned either off.
nonisolated struct SecretLifecycle: Equatable, Sendable {
    var rotation: RotationState?
    var rotatedAt: Date?
    var rotationOptOut = false
    var heartbeatOptOut = false
    /// Why the heartbeat cannot run right now, such as no target or no pinned host key.
    var heartbeatBlockedReason: String?
}
