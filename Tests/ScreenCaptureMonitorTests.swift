// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Sneakers_PAM
import Testing

private final class FakeScreenCaptureReporter: ScreenCaptureReporting, @unchecked Sendable {
    private(set) var reports: [ScreenCaptureReport] = []
    private(set) var devices: [String] = []
    var failure: VaultError?

    func report(_ report: ScreenCaptureReport, device: String, in _: ServerContext) async throws {
        reports.append(report)
        devices.append(device)
        if let failure {
            throw failure
        }
    }
}

@MainActor
struct ScreenCaptureMonitorTests {
    private let reporter = FakeScreenCaptureReporter()

    private func makeMonitor(revealed: [String], signedIn: Bool = true) -> ScreenCaptureMonitor {
        let access = VaultAccess(
            service: FakeVaultService(),
            context: { signedIn ? .fixture : nil },
            onSessionEnded: {}
        )
        return ScreenCaptureMonitor(
            access: access, reporter: reporter, revealedSecretIDs: { revealed }, deviceName: "iPhone"
        )
    }

    @Test func aScreenshotWhileASecretIsRevealedIsReportedForThatSecret() async {
        let monitor = makeMonitor(revealed: ["s1"])

        await monitor.screenshotTaken()

        #expect(reporter.reports == [ScreenCaptureReport(kind: .screenshot, secretID: "s1")])
        #expect(reporter.devices == ["iPhone"])
    }

    @Test func aScreenshotWithNothingRevealedReportsNothing() async {
        let monitor = makeMonitor(revealed: [])

        await monitor.screenshotTaken()

        #expect(reporter.reports.isEmpty)
    }

    @Test func eachRevealedSecretIsReportedOnceEvenWithSeveralFields() async {
        let monitor = makeMonitor(revealed: ["s2", "s1", "s1"])

        await monitor.screenshotTaken()

        #expect(reporter.reports.map(\.secretID) == ["s1", "s2"])
    }

    @Test func aRecordingStartingIsReportedButOnlyOnceUntilItStops() async {
        let monitor = makeMonitor(revealed: ["s1"])

        await monitor.recordingChanged(isCaptured: true)
        await monitor.recordingChanged(isCaptured: true)
        #expect(reporter.reports == [ScreenCaptureReport(kind: .screenRecording, secretID: "s1")])

        await monitor.recordingChanged(isCaptured: false)
        await monitor.recordingChanged(isCaptured: true)
        #expect(reporter.reports.count == 2)
    }

    @Test func aRecordingStoppingReportsNothing() async {
        let monitor = makeMonitor(revealed: ["s1"])

        await monitor.recordingChanged(isCaptured: false)

        #expect(reporter.reports.isEmpty)
    }

    @Test func aFailedReportIsSwallowedAndNeverBlocks() async {
        reporter.failure = .unreachable
        let monitor = makeMonitor(revealed: ["s1", "s2"])

        await monitor.screenshotTaken()

        #expect(reporter.reports.count == 2)
    }

    @Test func withoutASessionNothingIsSent() async {
        let monitor = makeMonitor(revealed: ["s1"], signedIn: false)

        await monitor.screenshotTaken()

        #expect(reporter.reports.isEmpty)
    }
}
