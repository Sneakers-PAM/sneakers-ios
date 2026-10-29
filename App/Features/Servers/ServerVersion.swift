// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// A server release such as v0.1.2. A pre-release or build suffix is ignored.
nonisolated struct ServerVersion: Hashable, Comparable, Codable, Sendable {
    let major: Int
    let minor: Int
    let patch: Int

    init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    init?(parsing text: String) {
        var core = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if core.hasPrefix("v") || core.hasPrefix("V") {
            core.removeFirst()
        }
        if let cut = core.firstIndex(where: { $0 == "-" || $0 == "+" }) {
            core = String(core[..<cut])
        }
        let parts = core.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }
        let numbers = parts.map { Int($0) }
        guard let major = numbers[0], let minor = numbers[1], let patch = numbers[2],
              parts.allSatisfy({ $0.allSatisfy(\.isNumber) }) else { return nil }
        self.init(major: major, minor: minor, patch: patch)
    }

    var line: ReleaseLine {
        ReleaseLine(major: major, minor: minor)
    }

    static func < (lhs: ServerVersion, rhs: ServerVersion) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }
}

/// A release line is a major and minor version. Patch releases within a line are all supported alike.
nonisolated struct ReleaseLine: Hashable, Comparable, Sendable {
    let major: Int
    let minor: Int

    static func < (lhs: ReleaseLine, rhs: ReleaseLine) -> Bool {
        (lhs.major, lhs.minor) < (rhs.major, rhs.minor)
    }
}

nonisolated enum ServerCompatibility: Equatable, Sendable {
    case supported
    case serverTooOld
    case appTooOld
}

/// Which server release lines this app release works with: the latest and the one before.
nonisolated struct ServerSupportPolicy: Sendable {
    let supportedLines: [ReleaseLine]

    /// The first server release is v0.1, so there is no earlier line to support yet.
    static let current = ServerSupportPolicy(supportedLines: [ReleaseLine(major: 0, minor: 1)])

    func check(_ version: ServerVersion) -> ServerCompatibility {
        if supportedLines.contains(version.line) {
            return .supported
        }
        if let oldest = supportedLines.min(), version.line < oldest {
            return .serverTooOld
        }
        return .appTooOld
    }
}
