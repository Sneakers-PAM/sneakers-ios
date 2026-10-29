// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Observation

/// Asking for access to a secret I can see but not read, with an optional reason. A request is sent once.
@MainActor
@Observable
final class AccessRequestModel {
    let secretID: String
    var reason = ""
    private(set) var isSending = false
    private(set) var didSend = false
    private(set) var message: String?

    init(secretID: String) {
        self.secretID = secretID
    }

    var canSend: Bool {
        !isSending && !didSend
    }

    func send(_ access: VaultAccess) async {
        guard canSend else { return }
        isSending = true
        message = nil
        defer { isSending = false }
        do {
            try await access.perform { try await access.service.requestAccess(
                secretID: self.secretID,
                reason: self.reason,
                $0
            ) }
            didSend = true
        } catch {
            message = (error as? VaultError ?? .unexpected).message
        }
    }
}
