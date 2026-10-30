// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import XCTest

/// Scanning a secret's QR code, with the pasted link standing in for the camera on the simulator.
final class ScanUITests: VaultUITestCase {
    private func openScanner(_ app: XCUIApplication) {
        let button = element(app, "scanButton")
        XCTAssertTrue(button.waitForExistence(timeout: 8), "the Scan button is missing")
        button.tap()
    }

    func testALinkToASecretOpensIt() {
        let app = launchSignedIn()
        openScanner(app)
        let field = app.textFields["scanLink"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "the link field is missing")
        field.tap()
        field.typeText("https://one.example.org/secret/s1")
        element(app, "scanOpen").tap()
        XCTAssertTrue(app.navigationBars["DB admin"].waitForExistence(timeout: 8), "the secret did not open")
    }

    func testALinkToAnotherSiteIsRefused() {
        let app = launchSignedIn()
        openScanner(app)
        let field = app.textFields["scanLink"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "the link field is missing")
        field.tap()
        field.typeText("https://elsewhere.example.com/secret/s1")
        element(app, "scanOpen").tap()
        XCTAssertTrue(element(app, "scanMessage").waitForExistence(timeout: 5), "no refusal was shown")
        XCTAssertFalse(app.navigationBars["DB admin"].exists)
    }
}
