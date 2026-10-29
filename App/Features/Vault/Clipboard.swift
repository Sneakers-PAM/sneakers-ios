// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import UIKit
import UniformTypeIdentifiers

/// Puts a value on the clipboard for a limited time. The real one is the system clipboard; tests fake it.
nonisolated protocol Clipboard: Sendable {
    func copy(_ value: String, clearAfter: TimeInterval)
}

nonisolated enum ClipboardPolicy {
    static let clearAfter: TimeInterval = 60
    static let copiedNotice = "Copied. It clears in 60 seconds."
}

/// The system clipboard, kept on this device and cleared by the system after the timeout, so a copied secret does
/// not travel to a person's other devices through Universal Clipboard.
nonisolated struct SystemClipboard: Clipboard {
    func copy(_ value: String, clearAfter: TimeInterval) {
        let expiry = Date().addingTimeInterval(clearAfter)
        UIPasteboard.general.setItems(
            [[UTType.plainText.identifier: value]],
            options: [.expirationDate: expiry, .localOnly: true]
        )
    }
}
