// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Testing

struct Sneakers_PAMTests {
    @Test func appBundleIdentifierIsStable() {
        #expect(Bundle.main.bundleIdentifier == "com.therabbithole.app.ios.sneakers-pam")
    }
}
