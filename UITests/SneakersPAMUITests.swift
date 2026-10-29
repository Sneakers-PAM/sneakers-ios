// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import XCTest

final class SneakersPAMUITests: XCTestCase {
    private static let appBundleIdentifier = "com.therabbithole.app.apple.sneakers-pam"

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ arguments: String...) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: Self.appBundleIdentifier)
        app.launchArguments = arguments
        app.launch()
        return app
    }

    private func skipOnIPad() throws {
        try XCTSkipIf(
            UIDevice.current.userInterfaceIdiom == .pad,
            "On an iPad the top tab bar hides Account behind its overflow chevron; the iPad layouts issue covers it."
        )
    }

    // MARK: First launch

    @MainActor
    func testFirstLaunchAsksForAServer() {
        let app = launch("-uiTestingEmptyServers")

        XCTAssertTrue(app.staticTexts["Add your server"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.textFields["serverAddress"].exists)
        XCTAssertFalse(app.buttons["checkAndAdd"].isEnabled)
    }

    @MainActor
    func testAnAddressThatIsNotHTTPSIsRefusedBeforeAnyNetworkCall() {
        let app = launch("-uiTestingEmptyServers")

        let field = app.textFields["serverAddress"]
        XCTAssertTrue(field.waitForExistence(timeout: 8))
        field.tap()
        field.typeText("http://sneakers.example.org")
        app.buttons["checkAndAdd"].tap()

        let message = app.staticTexts["serverMessage"]
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        XCTAssertEqual(message.label, "The address must use https. The app never connects without TLS.")
    }

    // MARK: Signed out

    @MainActor
    func testNothingShowsUntilThePersonIsSignedIn() {
        let app = launch("-uiTestingOneServer")

        XCTAssertTrue(
            app.staticTexts["Sign in to continue"].waitForExistence(timeout: 8),
            "the sign-in screen is missing"
        )
        XCTAssertTrue(app.textFields["signInUsername"].exists)
        XCTAssertFalse(app.buttons["signInButton"].isEnabled, "sign in must wait for a username and password")
        XCTAssertEqual(app.tabBars.count, 0, "the tabs must not exist before sign-in")
        XCTAssertFalse(app.buttons["Account"].exists)
        XCTAssertFalse(app.buttons["Folders"].exists)
    }

    @MainActor
    func testTheSignInButtonWaitsForBothFields() {
        let app = launch("-uiTestingOneServer")

        let username = app.textFields["signInUsername"]
        XCTAssertTrue(username.waitForExistence(timeout: 8))
        username.tap()
        username.typeText("alice")
        XCTAssertFalse(app.buttons["signInButton"].isEnabled)

        let password = app.secureTextFields["signInPassword"]
        password.tap()
        password.typeText("not-a-real-password")
        XCTAssertTrue(app.buttons["signInButton"].isEnabled)
    }

    @MainActor
    func testAFailedSignInShowsAMessageAndStaysOnTheScreen() {
        let app = launch("-uiTestingOneServer")

        let username = app.textFields["signInUsername"]
        XCTAssertTrue(username.waitForExistence(timeout: 8))
        username.tap()
        username.typeText("alice")
        let password = app.secureTextFields["signInPassword"]
        password.tap()
        password.typeText("not-a-real-password")
        app.buttons["signInButton"].tap()

        let message = app.staticTexts["signInMessage"]
        XCTAssertTrue(message.waitForExistence(timeout: 8))
        XCTAssertEqual(message.label, "Couldn't reach the server. Check your connection and try again.")
        XCTAssertEqual(app.tabBars.count, 0)
    }

    // MARK: Signed in

    @MainActor
    func testASignedInAppShowsTheTabs() {
        let app = launch("-uiTestingSignedIn")

        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 8), "the shell is missing")
        XCTAssertFalse(app.staticTexts["Sign in to continue"].exists)
    }

    @MainActor
    func testAServerThatRequiresASecondFactorShowsOnlyTheSetupScreen() {
        let app = launch("-uiTestingEnrolmentRequired")

        XCTAssertTrue(
            app.staticTexts["Set up an authenticator app"].waitForExistence(timeout: 8),
            "the setup screen is missing"
        )
        XCTAssertTrue(app.buttons["setupSignOut"].exists, "a person must be able to sign out of the wall")
        XCTAssertFalse(app.buttons["cancelSetup"].exists, "a required setup cannot be cancelled")
        XCTAssertEqual(app.tabBars.count, 0, "the tabs must not exist until a second factor is set up")
    }

    @MainActor
    func testALockedAppShowsOnlyTheLockScreen() {
        let app = launch("-uiTestingSignedIn", "-uiTestingLocked")

        XCTAssertTrue(app.staticTexts["Locked"].waitForExistence(timeout: 8), "the lock screen is missing")
        XCTAssertTrue(app.buttons["unlockButton"].exists)
        XCTAssertTrue(
            app.staticTexts["Unlock to open one.example.org."].exists,
            "the lock screen must say which server is being unlocked"
        )
        XCTAssertFalse(app.navigationBars["Home"].exists, "the app must not show behind the lock")
        XCTAssertEqual(app.tabBars.count, 0, "the tabs must not exist while locked")
    }

    @MainActor
    func testSigningOutBringsBackTheSignInScreenAndHidesTheTabs() throws {
        try skipOnIPad()
        let app = launch("-uiTestingSignedIn")

        let account = app.buttons["Account"].firstMatch
        XCTAssertTrue(account.waitForExistence(timeout: 8), "the Account tab is missing")
        account.tap()
        let signOut = app.buttons["signOut"]
        XCTAssertTrue(signOut.waitForExistence(timeout: 5), "the Sign out button is missing")
        signOut.tap()

        XCTAssertTrue(app.staticTexts["Sign in to continue"].waitForExistence(timeout: 8), "sign-in did not come back")
        XCTAssertEqual(app.tabBars.count, 0, "the tabs must be gone after sign-out")
    }

    @MainActor
    func testTheAddServerSheetCanBeCancelled() throws {
        try skipOnIPad()
        let app = launch("-uiTestingSignedIn")

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
}
