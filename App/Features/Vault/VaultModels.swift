// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

nonisolated struct Folder: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let parentId: String?
    let subtreeSecretCount: Int?
    var scope: String?
    var ownerUserId: String?
    var canManage: Bool?

    var isPersonal: Bool {
        scope == "personal"
    }

    /// How many secrets the folder holds, counting its subfolders. Empty when the server did not say.
    var secretCountText: String {
        switch subtreeSecretCount {
        case nil: ""
        case 0: "Empty"
        case 1: "1 secret"
        case let count?: "\(count) secrets"
        }
    }
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

    /// The one thing worth saying about a failed check beyond its status: a host key problem.
    var heartbeatNote: String? {
        switch lastHeartbeatResult {
        case "hostKeyNotPinned": "The target has no pinned host key, so it is not being checked."
        case "hostKeyMismatch": "The host offered a different key than the one that is pinned."
        default: nil
        }
    }

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

/// What kind of control a field needs. The gateway names more kinds over time, so an unknown one is plain text.
nonisolated enum FieldKind: Equatable, Sendable {
    case text, multiline, password, boolean, select, file, sensitive

    init(gateway name: String?) {
        switch name {
        case "multiline": self = .multiline
        case "password": self = .password
        case "boolean": self = .boolean
        case "select": self = .select
        case "file": self = .file
        case "sensitive": self = .sensitive
        default: self = .text
        }
    }
}

nonisolated struct FieldDefinition: Decodable, Equatable, Sendable {
    let key: String
    let label: String
    let kind: String?
    let sensitive: Bool?
    let superSensitive: Bool?
    var options: [String]?
    var required: Bool?
    var maxLength: Int?

    init(
        key: String,
        label: String,
        kind: String?,
        sensitive: Bool?,
        superSensitive: Bool?,
        options: [String]? = nil,
        required: Bool? = nil,
        maxLength: Int? = nil
    ) {
        self.key = key
        self.label = label
        self.kind = kind
        self.sensitive = sensitive
        self.superSensitive = superSensitive
        self.options = options
        self.required = required
        self.maxLength = maxLength
    }

    var fieldKind: FieldKind {
        FieldKind(gateway: kind)
    }

    var isRequired: Bool {
        required == true
    }

    /// A value kept out of sight until the server agrees to reveal it: a password or sensitive field, or one the
    /// type marks as sensitive.
    var isSensitive: Bool {
        fieldKind == .password || fieldKind == .sensitive || sensitive == true || superSensitive == true
    }
}

nonisolated struct SecretType: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let checkout: Bool?
    let fields: [FieldDefinition]?
    var heartbeat: Bool?
    var rotation: Bool?

    /// The field most people want when they ask for a secret: the first one that is sensitive.
    var primarySensitiveFieldKey: String? {
        fields?.first(where: \.isSensitive)?.key
    }

    var supportsCheckout: Bool {
        checkout == true
    }

    var supportsHeartbeat: Bool {
        heartbeat == true
    }

    var supportsRotation: Bool {
        rotation == true
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
    var lifecycle = SecretLifecycle()
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

    /// Every folder, in the order of their paths.
    func everyFolder() -> [Folder] {
        folders.sorted {
            (path(of: $0.id) ?? $0.name)
                .localizedCaseInsensitiveCompare(path(of: $1.id) ?? $1.name) == .orderedAscending
        }
    }

    /// The ids of every folder below one, however deep.
    func descendants(of folderID: String) -> [String] {
        var found: [String] = []
        var queue = [folderID]
        while let next = queue.popLast() {
            for child in children(of: next) where !found.contains(child.id) && child.id != folderID {
                found.append(child.id)
                queue.append(child.id)
            }
        }
        return found
    }

    func folder(_ id: String) -> Folder? {
        byID[id]
    }

    /// The folders nested for an outline. A folder that is only reachable through a cycle is left out.
    func nodes() -> [FolderNode] {
        nodes(under: nil, visited: [])
    }

    private func nodes(under parentID: String?, visited: Set<String>) -> [FolderNode] {
        children(of: parentID).compactMap { folder in
            guard !visited.contains(folder.id) else { return nil }
            let inner = nodes(under: folder.id, visited: visited.union([folder.id]))
            return FolderNode(id: folder.id, name: folder.name, children: inner.isEmpty ? nil : inner)
        }
    }
}

/// A folder with its subfolders, in the shape an outline list wants. Leaves have no children.
nonisolated struct FolderNode: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let children: [FolderNode]?
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
