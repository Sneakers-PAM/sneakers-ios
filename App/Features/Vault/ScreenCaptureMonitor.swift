// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Observation
import os

nonisolated enum ScreenCaptureKind: String, Equatable, Sendable {
    case screenshot = "SCREENSHOT"
    case screenRecording = "SCREEN_RECORDING"
}

/// One capture to tell the server about: what kind, and which revealed secret was on screen.
nonisolated struct ScreenCaptureReport: Equatable, Sendable {
    let kind: ScreenCaptureKind
    let secretID: String
}

/// Tells the server a screenshot or recording happened. The real one calls the gateway.
nonisolated protocol ScreenCaptureReporting: Sendable {
    func report(_ report: ScreenCaptureReport, device: String, in context: ServerContext) async throws
}

/// Reports screenshots and screen recordings taken while a secret is revealed. The system only says so after the fact,
/// so this logs to the audit trail and never blocks anything. A failed report is logged here and goes no further.
@MainActor
@Observable
final class ScreenCaptureMonitor {
    private static let logger = Logger(subsystem: "com.therabbithole.app.apple.sneakers-pam", category: "capture")

    private let access: VaultAccess
    private let reporter: ScreenCaptureReporting
    private let revealedSecretIDs: @MainActor () -> [String]
    private let deviceName: String
    @ObservationIgnored private var wasRecording = false

    init(
        access: VaultAccess,
        reporter: ScreenCaptureReporting,
        revealedSecretIDs: @escaping @MainActor () -> [String],
        deviceName: String
    ) {
        self.access = access
        self.reporter = reporter
        self.revealedSecretIDs = revealedSecretIDs
        self.deviceName = deviceName
    }

    func screenshotTaken() async {
        Self.logger.debug("screenshot noticed")
        await send(.screenshot)
    }

    /// Called whenever the screen's capture state changes. Only the start of a recording is reported.
    func recordingChanged(isCaptured: Bool) async {
        let started = isCaptured && !wasRecording
        wasRecording = isCaptured
        Self.logger.debug("capture state changed, started: \(started, privacy: .public)")
        if started {
            await send(.screenRecording)
        }
    }

    private func send(_ kind: ScreenCaptureKind) async {
        let secretIDs = Set(revealedSecretIDs()).sorted()
        guard !secretIDs.isEmpty else {
            Self.logger.trace("nothing revealed, no report")
            return
        }
        for secretID in secretIDs {
            let report = ScreenCaptureReport(kind: kind, secretID: secretID)
            do {
                try await access.perform { context in
                    try await reporter.report(report, device: deviceName, in: context)
                }
                Self.logger.info("capture reported: \(kind.rawValue, privacy: .public)")
            } catch {
                Self.logger.error("capture report failed: \(String(describing: error), privacy: .public)")
            }
        }
    }
}
