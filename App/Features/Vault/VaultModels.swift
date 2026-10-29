// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

nonisolated struct Folder: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let parentId: String?
    let subtreeSecretCount: Int?
}

nonisolated struct SecretStats: Decodable, Equatable, Sendable {
    let total: Int
    let expiringSoon: Int
    let expired: Int
    let drift: Int
}

/// A secret as listed. The value of a sensitive field is never part of it.
nonisolated struct SecretSummary: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let folderId: String?
    let typeId: String?
    let targetId: String?
    let lastHeartbeatResult: String?
    let retired: Bool?
    let canRead: Bool?
    let viewCount: Int?
    let lastAccessedAt: String?

    var health: HealthStatus {
        HealthStatus(heartbeatResult: lastHeartbeatResult, hasTarget: targetId?.isEmpty == false)
    }

    var isReadable: Bool {
        canRead ?? true
    }
}

nonisolated struct Lease: Decodable, Equatable, Sendable {
    let id: String
    let secretId: String
    let userId: String?
    let issuedAt: String
    let expiresAt: String
    let returned: Bool?

    var expiry: Date? {
        GatewayDate.parse(expiresAt)
    }
}

nonisolated struct FieldDefinition: Decodable, Equatable, Sendable {
    let key: String
    let label: String
    let kind: String?
    let sensitive: Bool?
    let superSensitive: Bool?

    var isSensitive: Bool {
        sensitive == true || superSensitive == true
    }
}

nonisolated struct SecretType: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let checkout: Bool?
    let fields: [FieldDefinition]?

    /// The field most people want when they ask for a secret: the first one that is sensitive.
    var primarySensitiveFieldKey: String? {
        fields?.first(where: \.isSensitive)?.key
    }

    var supportsCheckout: Bool {
        checkout == true
    }
}

nonisolated struct FieldValue: Decodable, Equatable, Sendable {
    let key: String
    let value: String?
}

/// One secret in full: its summary, its type, the values that are safe to show and who holds it.
nonisolated struct SecretDetail: Equatable, Sendable {
    let summary: SecretSummary
    let type: SecretType?
    let values: [String: String]
    let lease: Lease?
    let folderPath: String?
    let expiresAt: Date?
    let verifiedAt: Date?
    let nextRotationAt: Date?
}

/// Everything the Home dashboard shows, already joined.
nonisolated struct DashboardData: Equatable, Sendable {
    let stats: SecretStats
    let topSecrets: [SecretSummary]
    let leases: [LeaseWithName]
}

nonisolated struct LeaseWithName: Equatable, Sendable {
    let lease: Lease
    let secretName: String
}

nonisolated enum HealthStatus: Equatable, Sendable {
    case verified
    case drift
    case unreachable
    case unknown
    case none

    init(heartbeatResult: String?, hasTarget: Bool) {
        guard hasTarget else {
            self = .none
            return
        }
        switch heartbeatResult {
        case "ok": self = .verified
        case "failed": self = .drift
        case "unreachable": self = .unreachable
        default: self = .unknown
        }
    }

    var label: String {
        switch self {
        case .verified: "Verified"
        case .drift: "Drift"
        case .unreachable: "Unreachable"
        case .unknown: "Unknown"
        case .none: "No target"
        }
    }
}

/// Folders arrive as a flat list with parent ids. This builds the tree the screens walk.
nonisolated struct FolderTree: Sendable {
    private let folders: [Folder]
    private let byID: [String: Folder]

    init(folders: [Folder]) {
        self.folders = folders
        byID = Dictionary(folders.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    func children(of parentID: String?) -> [Folder] {
        folders
            .filter { ($0.parentId?.isEmpty == false ? $0.parentId : nil) == parentID }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func path(of folderID: String) -> String? {
        guard byID[folderID] != nil else { return nil }
        var names: [String] = []
        var visited: Set<String> = []
        var current: String? = folderID
        while let id = current, let folder = byID[id], !visited.contains(id) {
            visited.insert(id)
            names.append(folder.name)
            current = folder.parentId?.isEmpty == false ? folder.parentId : nil
        }
        return names.reversed().joined(separator: " / ")
    }

    func folder(_ id: String) -> Folder? {
        byID[id]
    }
}

/// The gateway sends timestamps as RFC 3339 text, and sometimes as seconds since 1970.
nonisolated enum GatewayDate {
    static func parse(_ text: String) -> Date? {
        guard !text.isEmpty else { return nil }
        if let seconds = TimeInterval(text) {
            return Date(timeIntervalSince1970: seconds)
        }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let date = plain.date(from: text) {
            return date
        }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: text)
    }
}

nonisolated enum LeaseCountdown {
    static func remaining(until expiry: Date, now: Date) -> TimeInterval {
        max(0, expiry.timeIntervalSince(now))
    }

    static func text(remaining: TimeInterval) -> String {
        guard remaining > 0 else { return "Expired" }
        let total = Int(remaining)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
