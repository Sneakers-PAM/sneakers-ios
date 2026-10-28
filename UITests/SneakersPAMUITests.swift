// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import XCTest

final class SneakersPAMUITests: XCTestCase {
    private static let appBundleIdentifier = "com.therabbithole.app.apple.sneakers-pam"

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchShowsContent() {
        let app = XCUIApplication(bundleIdentifier: Self.appBundleIdentifier)
        app.launch()

        XCTAssertTrue(app.staticTexts["Hello, world!"].waitForExistence(timeout: 5))
    }
}
