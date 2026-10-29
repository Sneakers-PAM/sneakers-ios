// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Observation
import os

nonisolated struct RevealKey: Hashable, Sendable {
    let secretID: String
    let fieldKey: String
    /// Set to read an earlier version's value instead of the current one.
    var versionNo: Int?
}

nonisolated enum PendingReveal: Equatable, Sendable {
    case show(RevealKey)
    case copy(RevealKey)
    case restore(secretID: String, versionNo: Int)
}

/// The server wants a fresh second factor before it will reveal a value.
struct StepUpPrompt: Equatable {
    let action: PendingReveal
    var message: String?
    var isWorking = false
}

/// The one place a revealed secret value ever lives. Values are held only while they are on screen, hide
/// themselves after a short time, and are cleared on lock, sign-out and backgrounding. Nothing here is logged.
@MainActor
@Observable
final class RevealCoordinator {
    private static let logger = Logger(subsystem: "com.therabbithole.app.apple.sneakers-pam", category: "reveal")

    private(set) var revealed: [RevealKey: String] = [:]
    var notice: String?
    private(set) var stepUp: StepUpPrompt?
    /// Goes up each time a version is restored, so a screen showing the secret knows to reload.
    private(set) var restoredCount = 0
    /// Reveals the vault is holding until someone approves them, by what was asked for.
    var held: [RevealKey: HeldReveal] = [:]

    let access: VaultAccess
    private let auth: AuthServicing
    let clipboard: Clipboard
    let pollEvery: Duration
    private let hideAfter: Duration
    @ObservationIgnored private var hideTasks: [RevealKey: Task<Void, Never>] = [:]
    @ObservationIgnored var heldTasks: [RevealKey: Task<Void, Never>] = [:]
    @ObservationIgnored var runIDs: [String: String] = [:]

    init(
        access: VaultAccess, auth: AuthServicing, clipboard: Clipboard,
        hideAfter: Duration = .seconds(20), pollEvery: Duration = .seconds(3)
    ) {
        self.access = access
        self.auth = auth
        self.clipboard = clipboard
        self.hideAfter = hideAfter
        self.pollEvery = pollEvery
    }

    func show(_ key: RevealKey) async {
        await run(.show(key))
    }

    func copy(_ key: RevealKey) async {
        await run(.copy(key))
    }

    /// Copies a value the screen already shows, one the server marks as safe, so no reveal is needed.
    func copyKnown(_ value: String) {
        clipboard.copy(value, clearAfter: ClipboardPolicy.clearAfter)
        notice = ClipboardPolicy.copiedNotice
    }

    func restore(secretID: String, versionNo: Int) async {
        await run(.restore(secretID: secretID, versionNo: versionNo))
    }

    func hide(_ key: RevealKey) {
        hideTasks[key]?.cancel()
        hideTasks[key] = nil
        revealed[key] = nil
    }

    func hideAll() {
        hideTasks.values.forEach { $0.cancel() }
        hideTasks = [:]
        heldTasks.values.forEach { $0.cancel() }
        heldTasks = [:]
        held = [:]
        revealed = [:]
        notice = nil
        stepUp = nil
    }

    func clearNotice() {
        notice = nil
    }

    // MARK: Step-up

    func submitStepUp(code: String, kind: SecondFactorKind) async {
        guard let prompt = stepUp else { return }
        guard code.count == 6, code.allSatisfy({ $0.isASCII && $0.isNumber }) else {
            stepUp?.message = "Enter the 6-digit code."
            return
        }
        stepUp?.isWorking = true
        stepUp?.message = nil
        do {
            let context = try access.context()
            try await auth.stepUp(on: context.server, session: context.session, kind: kind, code: code)
        } catch {
            fail(error)
            return
        }
        Self.logger.info("second factor proven again")
        stepUp = nil
        await run(prompt.action)
    }

    func sendStepUpEmail() async {
        guard stepUp != nil else { return }
        stepUp?.message = nil
        do {
            let context = try access.context()
            try await auth.sendStepUpEmail(on: context.server, session: context.session)
        } catch {
            fail(error)
        }
    }

    func cancelStepUp() {
        stepUp = nil
    }

    // MARK: Work

    private func run(_ action: PendingReveal) async {
        notice = nil
        do {
            switch action {
            case let .show(key):
                try await finish(action, value: fetch(key))
            case let .copy(key):
                try await finish(.copy(key), value: fetch(key))
            case let .restore(secretID, versionNo):
                try await access.perform { context in
                    try await self.access.service.restore(secretID: secretID, versionNo: versionNo, context)
                }
                restoredCount += 1
                notice = "Restored version \(versionNo)."
            }
        } catch VaultError.stepUpRequired {
            Self.logger.info("a fresh second factor is needed")
            stepUp = StepUpPrompt(action: action)
        } catch VaultError.approvalRequired {
            await hold(action)
        } catch let error as VaultError {
            notice = error.message
        } catch {
            notice = VaultError.unexpected.message
        }
    }

    /// Shows or copies a value that has been read. A restore has no value.
    func finish(_ action: PendingReveal, value: String) {
        switch action {
        case let .show(key):
            revealed[key] = value
            scheduleHide(key)
        case .copy:
            clipboard.copy(value, clearAfter: ClipboardPolicy.clearAfter)
            notice = ClipboardPolicy.copiedNotice
        case .restore:
            break
        }
    }

    /// The current value of a field, or an earlier version's when the key names one.
    private func fetch(_ key: RevealKey) async throws -> String {
        try await access.perform { context in
            if key.versionNo != nil {
                return try await self.access.service.revealVersion(key, context)
            }
            return try await self.access.service.reveal(secretID: key.secretID, fieldKey: key.fieldKey, context)
        }
    }

    func scheduleHide(_ key: RevealKey) {
        hideTasks[key]?.cancel()
        hideTasks[key] = Task { [hideAfter] in
            try? await Task.sleep(for: hideAfter)
            guard !Task.isCancelled else { return }
            hide(key)
        }
    }

    private func fail(_ error: Error) {
        let message: String
        if let failure = error as? AuthError {
            message = failure.message
            if failure == .sessionEnded {
                access.reportSessionEnded()
            }
        } else if let failure = error as? VaultError {
            message = failure.message
        } else {
            message = VaultError.unexpected.message
        }
        stepUp?.isWorking = false
        stepUp?.message = message
    }
}
