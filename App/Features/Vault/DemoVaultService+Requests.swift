// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

#if DEBUG
    import Foundation
    import os

    /// Requests and approvals in the made-up vault: one waiting for me, one of mine still open, one decided.
    extension DemoVaultService {
        func requestAccess(secretID _: String, reason _: String, _: ServerContext) async throws {}

        func requestsOverview(_: ServerContext) async throws -> RequestsOverview {
            demoOverview()
        }

        func resolve(requestID: String, approve: Bool, grantHours _: Int?, _: ServerContext) async throws {
            state.withLock { $0.decided[requestID] = approve ? .approved : .denied }
        }

        func comment(requestID _: String, body _: String, _: ServerContext) async throws {}

        func usesToDecide(_: ServerContext) async throws -> [SecretUse] {
            let done = state.withLock { $0.decidedUses }
            return demoUses().filter { !done.contains($0.id) }
        }

        func myPendingUses(_: ServerContext) async throws -> [SecretUse] {
            []
        }

        func decideUse(id: String, approve _: Bool, _: ServerContext) async throws {
            state.withLock { _ = $0.decidedUses.insert(id) }
        }

        func demoOverview() -> RequestsOverview {
            let decided = state.withLock { $0.decided }
            func request(
                _ id: String, secret: String, by user: String, status: ApprovalStatus, reason: String
            ) -> ApprovalRequest {
                ApprovalRequest(
                    id: id, kind: .secretAccess, secretID: secret, folderName: nil, destParentName: nil,
                    requestedByUserID: user, requestedAt: Date().addingTimeInterval(-3600), reason: reason,
                    status: decided[id] ?? status, resolvedAt: nil, resolvedByUserID: nil, resolvedByName: nil,
                    comments: []
                )
            }
            var requests = [request("r1", secret: "s1", by: "u-alice", status: .pending, reason: "On call tonight")]
            requests.append(request("r2", secret: "s8", by: "ui-test", status: .pending, reason: "Vendor audit"))
            requests.append(request("r3", secret: "s2", by: "ui-test", status: .approved, reason: "Deploy window"))
            return RequestsOverview(
                requests: requests,
                secretNames: ["s1": "DB admin", "s2": "Deploy key", "s8": "Vendor key"],
                secretsIMayApprove: ["s1"],
                people: ["u-alice": "Alice", "ui-test": "Me"]
            )
        }

        func demoUses() -> [SecretUse] {
            [SecretUse(
                id: "use-ci", secretName: "Deploy key", fieldKey: "password", state: "PENDING",
                expiresAt: Date().addingTimeInterval(900), purpose: "Roll out the nightly build", requester: "ci-bot",
                requestedBy: "Alice", confirm: false, runID: "run1"
            )]
        }
    }
#endif
