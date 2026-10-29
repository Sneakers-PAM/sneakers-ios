// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import XCTest

/// Home, browsing and a secret's fields, run against the made-up vault a debug build uses for `-uiTestingSignedIn`.
final class VaultUITests: XCTestCase {
    private static let appBundleIdentifier = "com.therabbithole.app.apple.sneakers-pam"
    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    override func setUp() {
        continueAfterFailure = false
    }

    private func launchSignedIn() -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: Self.appBundleIdentifier)
        app.launchArguments = ["-uiTestingSignedIn"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 10), "Home is missing")
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func openFolders(_ app: XCUIApplication) {
        let tab = app.buttons["Folders"].firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 8), "the Folders section is missing")
        tab.tap()
    }

    /// Taps a top-level folder. A portrait iPad keeps the folder column folded away until it is asked for.
    private func openFolder(_ app: XCUIApplication, _ name: String) {
        let folder = element(app, "folder.\(name)")
        if !folder.waitForExistence(timeout: 4) {
            let sidebar = app.buttons["Show Sidebar"].firstMatch
            if sidebar.exists {
                sidebar.tap()
            }
        }
        XCTAssertTrue(folder.waitForExistence(timeout: 8), "the folder list is missing")
        folder.tap()
    }

    /// Taps the list row, not the text inside it: an iPad ignores a tap on the combined text element.
    private func tapSecret(_ app: XCUIApplication, _ name: String) {
        let row = app.cells.containing(.staticText, identifier: "secret.\(name)").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 8), "the secret list is missing")
        row.tap()
    }

    /// Goes from Home to the demo secret's detail screen.
    private func openDemoSecret(_ app: XCUIApplication) {
        openFolders(app)
        openFolder(app, "Apps")
        tapSecret(app, "DB admin")
    }

    @MainActor
    func testHomeShowsTheCountsAndWhatIsCheckedOut() {
        let app = launchSignedIn()

        XCTAssertTrue(element(app, "homeTile.accessible").waitForExistence(timeout: 8), "the counts are missing")
        XCTAssertTrue(element(app, "homeTile.expiring").exists)
        XCTAssertTrue(element(app, "homeTile.expired").exists)
        XCTAssertTrue(element(app, "homeTile.drift").exists)
        XCTAssertTrue(app.staticTexts["Acme VPN"].exists, "the checked-out secret is missing")
    }

    @MainActor
    func testASecretCanBeFoundThroughTheFolders() {
        let app = launchSignedIn()
        openDemoSecret(app)

        XCTAssertTrue(element(app, "field.password").waitForExistence(timeout: 8), "the secret's fields are missing")
        XCTAssertTrue(app.staticTexts["app_admin"].exists, "a plain field should show its value")
    }

    @MainActor
    func testARevealAsksForAFreshCodeThenShowsTheValue() {
        let app = launchSignedIn()
        openDemoSecret(app)

        let reveal = element(app, "reveal.password")
        XCTAssertTrue(reveal.waitForExistence(timeout: 8), "the Reveal button is missing")
        reveal.tap()

        let verify = element(app, "stepUpVerify")
        XCTAssertTrue(verify.waitForExistence(timeout: 5), "the fresh-code screen did not appear")
        let code = app.textFields["codeField"]
        code.tap()
        code.typeText("123456")
        verify.tap()

        XCTAssertTrue(element(app, "revealedValue").waitForExistence(timeout: 8), "the value did not show")
        element(app, "hide.password").tap()
        XCTAssertFalse(element(app, "revealedValue").exists, "the value should be hidden again")
    }

    @MainActor
    func testCheckingOutAndInChangesTheButton() {
        let app = launchSignedIn()
        openDemoSecret(app)

        let checkOut = element(app, "checkOut")
        XCTAssertTrue(checkOut.waitForExistence(timeout: 8), "the Check out button is missing")
        checkOut.tap()
        let checkIn = element(app, "checkIn")
        XCTAssertTrue(checkIn.waitForExistence(timeout: 5), "Check in did not appear")
        checkIn.tap()
        XCTAssertTrue(element(app, "checkOut").waitForExistence(timeout: 5), "Check out did not come back")
    }

    @MainActor
    func testAnUnreadableSecretShowsALockInsteadOfFields() {
        let app = launchSignedIn()
        openFolders(app)
        openFolder(app, "Apps")
        tapSecret(app, "Vendor key")

        XCTAssertTrue(element(app, "noAccess").waitForExistence(timeout: 8), "the no-access note is missing")
        XCTAssertFalse(element(app, "field.password").exists)
    }

    @MainActor
    func testAnIPadHasAnAccountButtonInsteadOfATab() throws {
        try XCTSkipUnless(isPad, "iPad only")
        let app = launchSignedIn()

        XCTAssertTrue(element(app, "accountButton").waitForExistence(timeout: 8), "the Account button is missing")
    }
}
