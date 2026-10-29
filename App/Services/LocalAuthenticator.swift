// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import LocalAuthentication

/// Checks the owner with Face ID or Touch ID, falling back to the device passcode.
nonisolated struct LocalAuthenticator: Authenticating {
    func authenticate(reason: String) async -> LockResult {
        let context = LAContext()
        var availability: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &availability) else {
            return .notAvailable
        }
        do {
            let succeeded = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            return succeeded ? .success : .failed
        } catch let error as LAError {
            switch error.code {
            case .userCancel, .systemCancel, .appCancel:
                return .cancelled
            case .passcodeNotSet:
                return .notAvailable
            default:
                return .failed
            }
        } catch {
            return .failed
        }
    }
}

/// Keeps the on or off choice in the app's own defaults. The lock is on until the person turns it off.
struct UserDefaultsLockSettings: LockSettingStoring {
    static let key = "lock.enabled"

    var defaults: UserDefaults = .standard

    func load() -> Bool {
        defaults.object(forKey: Self.key) as? Bool ?? true
    }

    func save(_ isEnabled: Bool) {
        defaults.set(isEnabled, forKey: Self.key)
    }
}
