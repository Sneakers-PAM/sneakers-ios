// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

nonisolated enum LockResult: Equatable, Sendable {
    case success
    case cancelled
    case failed
    /// The device cannot check the person at all, because it has no passcode.
    case notAvailable
}

/// Asks the device to check that the owner is there, with Face ID, Touch ID or the passcode.
nonisolated protocol Authenticating: Sendable {
    func authenticate(reason: String) async -> LockResult
}

/// Remembers whether the person turned the lock on. It is on unless they turn it off.
nonisolated protocol LockSettingStoring {
    func load() -> Bool
    func save(_ isEnabled: Bool)
}

/// The words on the lock screen. The check is the phone's own, so it says device passcode, never anything about the
/// Sneakers account.
nonisolated enum LockContent {
    static let instruction = "Use Face ID, Touch ID or your device passcode."
    static let settingLabel = "Lock with Face ID or device passcode"

    static func subtitle(serverName: String?) -> String {
        "Unlock to open \(serverName ?? "Sneakers-PAM")."
    }

    static func reason(serverName: String?) -> String {
        serverName.map { "Unlock Sneakers-PAM for \($0)" } ?? "Unlock Sneakers-PAM"
    }
}

/// When the app locks itself after it has been out of sight.
nonisolated struct LockPolicy: Sendable {
    static let standard = LockPolicy(gracePeriod: 30)

    /// How long the app can be in the background before it asks again.
    let gracePeriod: TimeInterval

    func shouldLock(backgroundedAt: Date?, now: Date) -> Bool {
        guard let backgroundedAt else { return false }
        let away = now.timeIntervalSince(backgroundedAt)
        return away < 0 || away >= gracePeriod
    }
}
