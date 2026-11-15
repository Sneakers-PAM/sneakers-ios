// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Sneakers_PAM
import Testing

struct HTTPScreenCaptureReporterTests {
    private let transport = FakeGraphQLTransport()

    @Test func aScreenshotIsSentAsTheGatewaysReportScreenCaptureMutation() async throws {
        transport.answer("ReportScreenCapture", #"{"reportScreenCapture":true}"#)
        let reporter = HTTPScreenCaptureReporter(transport: transport)

        try await reporter.report(
            ScreenCaptureReport(kind: .screenshot, secretID: "s1"),
            device: "iPhone",
            in: .fixture
        )

        let sent = try #require(transport.operation(named: "ReportScreenCapture"))
        #expect(sent.query.contains("reportScreenCapture(input: $input)"))
        var expected: [String: GraphQLValue] = ["kind": .string("SCREENSHOT"), "secretId": .string("s1")]
        expected["clientKind"] = .string("ios")
        expected["device"] = .string("iPhone")
        #expect(sent.variables["input"] == .object(expected))
    }

    @Test func aRecordingUsesTheRecordingKind() async throws {
        transport.answer("ReportScreenCapture", #"{"reportScreenCapture":true}"#)
        let reporter = HTTPScreenCaptureReporter(transport: transport)

        try await reporter.report(
            ScreenCaptureReport(kind: .screenRecording, secretID: "s1"), device: "iPhone", in: .fixture
        )

        let sent = try #require(transport.operation(named: "ReportScreenCapture"))
        guard case let .object(input)? = sent.variables["input"] else {
            Issue.record("no input")
            return
        }
        #expect(input["kind"] == .string("SCREEN_RECORDING"))
    }
}
