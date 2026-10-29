// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// Reveals held for approval.
extension HTTPVaultService {
    func prepareReveal(_ key: RevealKey, runID: String, _ context: ServerContext) async throws -> HeldReveal {
        let use = try await run(
            Operations.prepareReveal(key, runID: runID), as: PrepareResponse.self, in: context
        ).prepareSecretReveal
        return HeldReveal(
            id: use.id, state: use.state, confirm: use.confirm,
            expiresAt: Date(timeIntervalSince1970: TimeInterval(use.expiresAtUnix)), runID: use.runId
        )
    }

    func redeemReveal(useID: String, _ context: ServerContext) async throws -> String {
        try await run(Operations.redeemReveal(useID: useID), as: RedeemResponse.self, in: context).redeemSecretReveal
    }

    private struct WireUse: Decodable {
        let id: String
        let state: String
        let confirm: Bool
        let expiresAtUnix: Int
        let runId: String?
    }

    private struct PrepareResponse: Decodable {
        let prepareSecretReveal: WireUse
    }

    private struct RedeemResponse: Decodable {
        let redeemSecretReveal: String
    }
}
