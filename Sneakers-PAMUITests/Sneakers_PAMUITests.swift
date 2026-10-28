// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import XCTest

final class Sneakers_PAMUITests: XCTestCase {
    private static let appBundleIdentifier = "com.therabbithole.app.ios.sneakers-pam"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchShowsContent() throws {
        let app = XCUIApplication(bundleIdentifier: Self.appBundleIdentifier)
        app.launch()

        XCTAssertTrue(app.staticTexts["Hello, world!"].waitForExistence(timeout: 5))
    }
}
