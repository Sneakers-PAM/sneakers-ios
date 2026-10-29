// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Observation
import os

/// Whether the app is locked, covered while out of sight, and the setting that turns the lock on or off.
@MainActor
@Observable
final class AppLockModel {
    private static let logger = Logger(subsystem: "com.therabbithole.app.apple.sneakers-pam", category: "lock")

    private(set) var isLocked: Bool
    private(set) var isEnabled: Bool
    /// True while the app is not on screen, so the app switcher shows a cover and not the person's secrets.
    private(set) var isCovered = false
    private(set) var isAuthenticating = false
    private(set) var message: String?
    /// The device has no passcode, so it cannot check anyone and the lock cannot do its job.
    private(set) var deviceCannotLock = false

    private let authenticator: Authenticating
    private let settings: LockSettingStoring
    private let policy: LockPolicy
    private var backgroundedAt: Date?

    init(authenticator: Authenticating, settings: LockSettingStoring, policy: LockPolicy = .standard) {
        self.authenticator = authenticator
        self.settings = settings
        self.policy = policy
        let enabled = settings.load()
        isEnabled = enabled
        isLocked = enabled
    }

    func unlock(reason: String = LockContent.reason(serverName: nil)) async {
        guard isLocked, !isAuthenticating else { return }
        isAuthenticating = true
        message = nil
        defer { isAuthenticating = false }

        let result = await authenticator.authenticate(reason: reason)
        switch result {
        case .success:
            Self.logger.info("unlocked")
            isLocked = false
        case .cancelled:
            Self.logger.debug("unlock cancelled")
        case .failed:
            Self.logger.info("unlock failed")
            message = "Couldn't unlock. Try again."
        case .notAvailable:
            Self.logger.info("this device has no passcode, so the lock cannot work")
            deviceCannotLock = true
            isLocked = false
        }
    }

    func movedToBackground(at date: Date) {
        backgroundedAt = backgroundedAt ?? date
        isCovered = true
        Self.logger.debug("moved to the background")
    }

    func becameActive(at date: Date) {
        isCovered = false
        if isEnabled, !isLocked, policy.shouldLock(backgroundedAt: backgroundedAt, now: date) {
            Self.logger.info("locked after time in the background")
            isLocked = true
        }
        backgroundedAt = nil
    }

    /// The person just proved who they are with a password and a second factor, so do not ask again.
    func signedInJustNow() {
        isLocked = false
        message = nil
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        settings.save(enabled)
        if !enabled {
            isLocked = false
            message = nil
        }
        Self.logger.info("lock turned \(enabled ? "on" : "off", privacy: .public)")
    }
}
