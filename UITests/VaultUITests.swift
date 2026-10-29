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

    /// Taps once the row has stopped moving: a tap during a push or a column change is dropped.
    private func tapWhenSettled(_ row: XCUIElement) {
        let settled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: row)
        _ = XCTWaiter().wait(for: [settled], timeout: 8)
        Thread.sleep(forTimeInterval: 0.6)
        row.tap()
    }

    /// Taps a folder row. A portrait iPad keeps the folder column folded away until it is asked for.
    private func openFolder(_ app: XCUIApplication, _ name: String) {
        let row = app.cells.containing(.any, identifier: "folder.\(name)").firstMatch
        if !row.waitForExistence(timeout: 4) {
            let sidebar = app.buttons["Show Sidebar"].firstMatch
            if sidebar.exists {
                sidebar.tap()
            }
        }
        XCTAssertTrue(row.waitForExistence(timeout: 8), "the folder \(name) is missing")
        tapWhenSettled(row)
    }

    /// Taps the list row, not the text inside it: an iPad ignores a tap on the combined text element.
    private func tapSecret(_ app: XCUIApplication, _ name: String) {
        let row = app.cells.containing(.any, identifier: "secret.\(name)").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 8), "the secret list is missing")
        tapWhenSettled(row)
    }

    /// Scrolls a long screen until the element is on it, since a list only builds the rows it shows.
    private func scrollTo(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        let target = element(app, identifier)
        for _ in 0 ..< 6 where !(target.exists && target.isHittable) {
            app.swipeUp()
        }
        return target
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
    func testTheFourCountsAreTheSameSizeAndFillTheRow() {
        let app = launchSignedIn()
        let tiles = ["accessible", "expiring", "expired", "drift"].map { element(app, "homeTile.\($0)") }
        XCTAssertTrue(tiles[0].waitForExistence(timeout: 8), "the counts are missing")

        let sizes = tiles.map(\.frame.size)
        XCTAssertTrue(sizes.allSatisfy { abs($0.width - sizes[0].width) < 1 }, "the widths differ: \(sizes)")
        XCTAssertTrue(sizes.allSatisfy { abs($0.height - sizes[0].height) < 1 }, "the heights differ: \(sizes)")
        if isPad {
            XCTAssertTrue(tiles.allSatisfy { abs($0.frame.minY - tiles[0].frame.minY) < 1 }, "not in one row")
        }
    }

    @MainActor
    func testAFolderThatHoldsOnlyFoldersLetsYouWalkDownToItsSecrets() {
        let app = launchSignedIn()
        openFolders(app)
        openFolder(app, "Platform")
        XCTAssertFalse(element(app, "secret.Deploy key").exists, "the secret lives one level down")
        openFolder(app, "Databases")
        tapSecret(app, "Deploy key")

        XCTAssertTrue(element(app, "field.password").waitForExistence(timeout: 8), "the secret did not open")
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
    func testEditingAFieldSavesAndShowsTheNewValue() {
        let app = launchSignedIn()
        openDemoSecret(app)

        let edit = element(app, "editSecret")
        XCTAssertTrue(edit.waitForExistence(timeout: 8), "the Edit button is missing")
        edit.tap()

        let username = app.textFields["Username"]
        XCTAssertTrue(username.waitForExistence(timeout: 5), "the username control is missing")
        username.tap()
        username.press(forDuration: 1.0)
        if app.menuItems["Select All"].waitForExistence(timeout: 2) {
            app.menuItems["Select All"].tap()
        }
        username.typeText("bob")
        element(app, "editSave").tap()

        XCTAssertTrue(app.staticTexts["bob"].waitForExistence(timeout: 8), "the new value did not show")
    }

    @MainActor
    func testTheHistoryListsVersionsAndAnOldValueCanBeRevealedAndRestored() {
        let app = launchSignedIn()
        openDemoSecret(app)

        let history = element(app, "history")
        XCTAssertTrue(history.waitForExistence(timeout: 8), "the History link is missing")
        history.tap()

        let first = element(app, "version.1")
        XCTAssertTrue(first.waitForExistence(timeout: 8), "the versions are missing")
        XCTAssertTrue(element(app, "version.2").exists)
        first.tap()

        let reveal = element(app, "revealOld.password.1")
        XCTAssertTrue(reveal.waitForExistence(timeout: 5), "the old value cannot be revealed")
        reveal.tap()
        XCTAssertTrue(element(app, "oldValue").waitForExistence(timeout: 8), "the old value did not show")

        let restore = element(app, "restore.1")
        XCTAssertTrue(restore.waitForExistence(timeout: 5), "the restore button is missing")
        restore.tap()
        let confirm = app.buttons["restoreConfirm"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "the confirmation is missing")
        Thread.sleep(forTimeInterval: 0.5)
        confirm.tap()
        XCTAssertTrue(app.staticTexts["Restored version 1."].waitForExistence(timeout: 8), "restore did not report")
    }

    @MainActor
    func testCopyingAPlainFieldSaysItCopiedAndWhenItClears() {
        let app = launchSignedIn()
        openDemoSecret(app)

        let copy = element(app, "copy.username")
        XCTAssertTrue(copy.waitForExistence(timeout: 8), "the Copy button is missing")
        copy.tap()

        XCTAssertTrue(element(app, "notice").waitForExistence(timeout: 5), "the copy notice did not show")
    }

    @MainActor
    func testTheHeartbeatShowsItsStatusAndCanBeSwitchedOff() {
        let app = launchSignedIn()
        openDemoSecret(app)

        XCTAssertTrue(element(app, "healthPill").waitForExistence(timeout: 8), "the heartbeat status is missing")
        let toggle = scrollTo(app, "heartbeatToggle")
        XCTAssertTrue(toggle.exists, "the heartbeat switch is missing")
        XCTAssertEqual(toggle.value as? String, "1", "checking should start on")
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        XCTAssertTrue(
            app.staticTexts["Checking is switched off for this secret."].waitForExistence(timeout: 8),
            "the heartbeat did not switch off"
        )
    }

    @MainActor
    func testRotatingNowAsksFirstAndThenShowsItRotated() {
        let app = launchSignedIn()
        openDemoSecret(app)

        let rotate = scrollTo(app, "rotateNow")
        XCTAssertTrue(rotate.exists, "Rotate now is missing")
        rotate.tap()
        let confirm = scrollTo(app, "rotateConfirm")
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "the confirmation is missing")
        confirm.tap()

        XCTAssertTrue(app.staticTexts["Rotated"].waitForExistence(timeout: 8), "the rotation did not show")
    }

    @MainActor
    func testARetiredSecretShowsItAndCanBeRestored() {
        let app = launchSignedIn()
        openDemoSecret(app)

        let retire = scrollTo(app, "retire")
        XCTAssertTrue(retire.exists, "Retire is missing")
        retire.tap()
        let confirm = scrollTo(app, "retireConfirm")
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "the confirmation is missing")
        confirm.tap()

        XCTAssertTrue(scrollTo(app, "retiredBanner").waitForExistence(timeout: 8), "the secret is not shown retired")
        let reinstate = scrollTo(app, "reinstate")
        reinstate.tap()
        XCTAssertTrue(scrollTo(app, "retire").waitForExistence(timeout: 8), "the secret was not restored")
    }

    @MainActor
    func testASecretIMayOnlyReadHasNoEditButton() {
        let app = launchSignedIn()
        openFolders(app)
        openFolder(app, "Apps")
        tapSecret(app, "Vendor key")

        XCTAssertTrue(element(app, "noAccess").waitForExistence(timeout: 8))
        XCTAssertFalse(element(app, "editSecret").exists)
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
