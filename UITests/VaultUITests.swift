// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import XCTest

// Home, browsing and a secret's fields, run against the made-up vault a debug build uses for `-uiTestingSignedIn`.

/// Home, browsing and a secret's fields, run against the made-up vault a debug build uses for `-uiTestingSignedIn`.
final class VaultUITests: VaultUITestCase {
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
    func testCopyingAPlainFieldSaysItCopiedAndWhenItClears() {
        let app = launchSignedIn()
        openDemoSecret(app)

        let copy = element(app, "copy.username")
        XCTAssertTrue(copy.waitForExistence(timeout: 8), "the Copy button is missing")
        copy.tap()

        XCTAssertTrue(element(app, "notice").waitForExistence(timeout: 5), "the copy notice did not show")
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
