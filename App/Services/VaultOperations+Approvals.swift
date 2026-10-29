// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// Reveals the vault holds for approval, and the requests people make.
nonisolated extension Operations {
    static func prepareReveal(_ key: RevealKey, runID: String) -> GraphQLOperation {
        GraphQLOperation(
            name: "SecretPrepareReveal",
            query: """
            mutation SecretPrepareReveal($secretId: ID!, $fieldKey: String!, $runId: ID) {
              prepareSecretReveal(secretId: $secretId, fieldKey: $fieldKey, runId: $runId) {
                id state confirm expiresAtUnix runId
              }
            }
            """,
            variables: ["secretId": .string(key.secretID), "fieldKey": .string(key.fieldKey), "runId": .string(runID)]
        )
    }

    static func redeemReveal(useID: String) -> GraphQLOperation {
        GraphQLOperation(
            name: "SecretRedeemReveal",
            query: "mutation SecretRedeemReveal($id: ID!) { redeemSecretReveal(id: $id) }",
            variables: ["id": .string(useID)]
        )
    }
}
