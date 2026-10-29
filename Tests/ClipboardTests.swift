// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

@testable import Sneakers_PAM
import Testing
import UIKit

struct ClipboardTests {
    @Test func theClipboardClearsAfterAMinute() {
        #expect(ClipboardPolicy.clearAfter == 60)
    }

    @Test func theNoticeSaysWhenTheCopyClears() {
        #expect(ClipboardPolicy.copiedNotice == "Copied. It clears in 60 seconds.")
    }

    @Test func theSystemClipboardHoldsTheValueForTheApp() {
        let clipboard = SystemClipboard()

        clipboard.copy("a-test-value", clearAfter: 60)

        #expect(UIPasteboard.general.string == "a-test-value")
        UIPasteboard.general.string = ""
    }
}
