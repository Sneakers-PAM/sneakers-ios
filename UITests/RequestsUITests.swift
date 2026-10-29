// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import XCTest

/// The Requests and Approvals screens on the demo vault: one request and one reveal waiting on me, one request of mine
/// still open and one decided.
final class RequestsUITests: VaultUITestCase {
    private func openTab(_ app: XCUIApplication, _ name: String) {
        let tab = app.buttons[name].firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 8), "the \(name) section is missing")
        tab.tap()
    }

    @MainActor
    func testApprovalsListsTheRequestAndTheRevealWaitingOnMe() {
        let app = launchSignedIn()
        openTab(app, "Approvals")

        XCTAssertTrue(element(app, "request.r1").waitForExistence(timeout: 10), "the request is missing")
        XCTAssertTrue(app.staticTexts["Access to DB admin"].exists)
        XCTAssertTrue(element(app, "use.use-ci").exists, "the reveal is missing")
        XCTAssertTrue(app.staticTexts["Roll out the nightly build"].exists, "the reveal's purpose is missing")
    }

    @MainActor
    func testApprovingARequestChoosesHowLongAndTakesItOffTheList() {
        let app = launchSignedIn()
        openTab(app, "Approvals")

        let approve = element(app, "approve.r1")
        XCTAssertTrue(approve.waitForExistence(timeout: 10), "Approve is missing")
        approve.tap()
        let four = element(app, "approve.r1.4")
        XCTAssertTrue(four.waitForExistence(timeout: 5), "the hours are missing")
        four.tap()

        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: element(app, "approve.r1"))
        waitForExpectations(timeout: 10)
    }

    @MainActor
    func testDenyingARevealTakesItOffTheList() {
        let app = launchSignedIn()
        openTab(app, "Approvals")

        let deny = element(app, "denyUse.use-ci")
        XCTAssertTrue(deny.waitForExistence(timeout: 10), "Deny is missing")
        deny.tap()

        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: element(app, "use.use-ci"))
        waitForExpectations(timeout: 10)
    }

    @MainActor
    func testRequestsShowsWhatIAskedForAndWhatWasDecided() {
        let app = launchSignedIn()
        openTab(app, "Requests")

        XCTAssertTrue(element(app, "request.r2").waitForExistence(timeout: 10), "my open request is missing")
        XCTAssertTrue(app.staticTexts["Access to Vendor key"].exists)
        XCTAssertTrue(element(app, "request.r3").exists, "my decided request is missing")
        XCTAssertFalse(element(app, "request.r1").exists, "someone else's request is not mine")
    }
}
