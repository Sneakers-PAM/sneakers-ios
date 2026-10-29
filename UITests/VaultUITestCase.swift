// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import XCTest

/// What the vault UI tests share: launching the signed-in demo app and walking to a secret.
class VaultUITestCase: XCTestCase {
    private static let appBundleIdentifier = "com.therabbithole.app.apple.sneakers-pam"
    var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    override func setUp() {
        continueAfterFailure = false
    }

    func launchSignedIn() -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: Self.appBundleIdentifier)
        app.launchArguments = ["-uiTestingSignedIn"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 10), "Home is missing")
        return app
    }

    func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func openFolders(_ app: XCUIApplication) {
        let tab = app.buttons["Folders"].firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 8), "the Folders section is missing")
        tab.tap()
    }

    /// Taps once the row has stopped moving: a tap during a push or a column change is dropped.
    func tapWhenSettled(_ row: XCUIElement) {
        let settled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: row)
        _ = XCTWaiter().wait(for: [settled], timeout: 8)
        Thread.sleep(forTimeInterval: 0.6)
        row.tap()
    }

    /// Taps a folder row. A portrait iPad keeps the folder column folded away until it is asked for.
    func openFolder(_ app: XCUIApplication, _ name: String) {
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
    func tapSecret(_ app: XCUIApplication, _ name: String) {
        let row = app.cells.containing(.any, identifier: "secret.\(name)").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 8), "the secret list is missing")
        tapWhenSettled(row)
    }

    /// Scrolls a long screen until the element is on it, since a list only builds the rows it shows.
    func scrollTo(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        let target = element(app, identifier)
        for _ in 0 ..< 6 where !(target.exists && target.isHittable) {
            app.swipeUp()
        }
        return target
    }

    /// Goes from Home to the demo secret's detail screen.
    func openDemoSecret(_ app: XCUIApplication) {
        openFolders(app)
        openFolder(app, "Apps")
        tapSecret(app, "DB admin")
    }
}
