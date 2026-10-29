// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import XCTest

final class SneakersPAMUITests: XCTestCase {
    private static let appBundleIdentifier = "com.therabbithole.app.apple.sneakers-pam"

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testFirstLaunchAsksForAServer() {
        let app = XCUIApplication(bundleIdentifier: Self.appBundleIdentifier)
        app.launchArguments = ["-uiTestingEmptyServers"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Add your server"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.textFields["serverAddress"].exists)
        XCTAssertFalse(app.buttons["checkAndAdd"].isEnabled)
    }

    @MainActor
    func testAnAddressThatIsNotHTTPSIsRefusedBeforeAnyNetworkCall() {
        let app = XCUIApplication(bundleIdentifier: Self.appBundleIdentifier)
        app.launchArguments = ["-uiTestingEmptyServers"]
        app.launch()

        let field = app.textFields["serverAddress"]
        XCTAssertTrue(field.waitForExistence(timeout: 8))
        field.tap()
        field.typeText("http://sneakers.example.org")
        app.buttons["checkAndAdd"].tap()

        let message = app.staticTexts["serverMessage"]
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        XCTAssertEqual(message.label, "The address must use https. The app never connects without TLS.")
    }
}
