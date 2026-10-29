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
    func testTheAddServerSheetCanBeCancelled() throws {
        try XCTSkipIf(
            UIDevice.current.userInterfaceIdiom == .pad,
            "On an iPad the top tab bar hides Account behind its overflow chevron; the iPad layouts issue covers it."
        )
        let app = XCUIApplication(bundleIdentifier: Self.appBundleIdentifier)
        app.launchArguments = ["-uiTestingOneServer"]
        app.launch()

        let account = app.buttons["Account"].firstMatch
        XCTAssertTrue(account.waitForExistence(timeout: 8), "the Account tab is missing")
        account.tap()

        let add = app.descendants(matching: .any).matching(identifier: "Add server").firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 5), "the Add server button is missing")
        add.tap()

        let cancel = app.buttons["cancelAddServer"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), "the Cancel button is missing")
        cancel.tap()

        XCTAssertTrue(app.navigationBars["Account"].waitForExistence(timeout: 5), "Account did not come back")
        XCTAssertFalse(app.staticTexts["Add your server"].exists, "the sheet is still showing")
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
