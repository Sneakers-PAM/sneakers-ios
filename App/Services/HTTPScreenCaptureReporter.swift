// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// Sends the gateway's `reportScreenCapture` mutation, which writes an audit event and carries no secret value.
nonisolated struct HTTPScreenCaptureReporter: ScreenCaptureReporting {
    var transport: GraphQLTransport = HTTPGraphQLTransport()

    func report(_ report: ScreenCaptureReport, device: String, in context: ServerContext) async throws {
        _ = try await transport.execute(Self.operation(for: report, device: device), in: context)
    }

    static func operation(for report: ScreenCaptureReport, device: String) -> GraphQLOperation {
        var input: [String: GraphQLValue] = ["kind": .string(report.kind.rawValue)]
        input["secretId"] = .string(report.secretID)
        input["clientKind"] = .string("ios")
        input["device"] = .string(String(device.prefix(80)))
        return GraphQLOperation(
            name: "ReportScreenCapture",
            query: """
            mutation ReportScreenCapture($input: ScreenCaptureInput!) {
              reportScreenCapture(input: $input)
            }
            """,
            variables: ["input": .object(input)]
        )
    }
}
