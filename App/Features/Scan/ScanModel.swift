// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Observation
import os

/// Reads a scanned or pasted secret link and says which secret to open.
@MainActor
@Observable
final class ScanModel {
    private static let logger = Logger(subsystem: "com.therabbithole.app.apple.sneakers-pam", category: "scan")
    static let wrongCodeMessage = "That code isn't a secret on this server."

    private(set) var openedSecretID: String?
    private(set) var message: String?
    var pasted = ""

    private let server: ServerURL

    init(server: ServerURL, startingWith link: String? = nil) {
        self.server = server
        if let link {
            scanned(link)
        }
    }

    func scanned(_ text: String) {
        if let id = SecretLink.secretID(in: text, on: server) {
            Self.logger.info("a secret link was read")
            message = nil
            openedSecretID = id
        } else {
            Self.logger.info("a code was refused")
            message = Self.wrongCodeMessage
        }
    }

    func openPasted() {
        scanned(pasted)
    }
}
