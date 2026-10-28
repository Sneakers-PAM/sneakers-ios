// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Testing

struct SneakersPAMTests {
    @Test func appBundleIdentifierIsStable() {
        #expect(Bundle.main.bundleIdentifier == "com.therabbithole.app.apple.sneakers-pam")
    }
}
