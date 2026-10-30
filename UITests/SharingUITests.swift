// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import XCTest

/// Who has access to a secret on the demo vault: the rules, adding people, groups and everyone, and the preview.
final class SharingUITests: VaultUITestCase {
    @MainActor
    func testWhoHasAccessShowsTheRulesAndASavedChangeSaysSo() {
        let app = launchSignedIn()
        openDemoSecret(app)

        let sharing = scrollTo(app, "sharing")
        XCTAssertTrue(sharing.waitForExistence(timeout: 8), "the sharing link is missing")
        tapWhenSettled(sharing)

        XCTAssertTrue(element(app, "rule.0").waitForExistence(timeout: 8), "the rules are missing")
        XCTAssertTrue(app.staticTexts["From Platform"].exists, "the inherited rule is missing")
        let save = element(app, "sharingSave")
        XCTAssertFalse(save.isEnabled, "nothing has changed yet")

        element(app, "cell.0.manage").tap()
        XCTAssertTrue(save.isEnabled, "a change should allow saving")
        save.tap()
        XCTAssertTrue(element(app, "sharingSaved").waitForExistence(timeout: 8), "the save did not report")
    }

    @MainActor
    func testAPersonCanBeFoundAndAddedToTheRules() {
        let app = launchSignedIn()
        openDemoSecret(app)

        let sharing = scrollTo(app, "sharing")
        tapWhenSettled(sharing)
        let field = scrollTo(app, "addPersonField")
        XCTAssertTrue(field.waitForExistence(timeout: 8), "the search field is missing")
        field.tap()
        field.typeText("Ev")

        let eve = scrollTo(app, "person.Eve")
        XCTAssertTrue(eve.waitForExistence(timeout: 8), "the search found nobody")
        eve.tap()
        XCTAssertTrue(element(app, "rule.1").waitForExistence(timeout: 5), "the person was not added")
    }

    @MainActor
    func testAPersonsAccessCanBePreviewedBeforeSaving() {
        let app = launchSignedIn()
        openDemoSecret(app)
        tapWhenSettled(scrollTo(app, "sharing"))

        let preview = element(app, "preview.0")
        XCTAssertFalse(preview.exists, "a group rule has nothing to preview")
        let field = scrollTo(app, "addPersonField")
        field.tap()
        field.typeText("Ev")
        let eve = scrollTo(app, "person.Eve")
        XCTAssertTrue(eve.waitForExistence(timeout: 8), "the search found nobody")
        eve.tap()

        let previewEve = scrollTo(app, "preview.1")
        XCTAssertTrue(previewEve.waitForExistence(timeout: 5), "Preview is missing for a person")
        previewEve.tap()
        XCTAssertTrue(element(app, "previewCard").waitForExistence(timeout: 8), "the preview did not show")
        XCTAssertTrue(app.staticTexts["Allowed by DB team"].exists, "the reason is missing")
    }

    @MainActor
    func testEveryoneAndAGroupCanBeAddedAsRules() {
        let app = launchSignedIn()
        openDemoSecret(app)
        tapWhenSettled(scrollTo(app, "sharing"))

        let everyone = scrollTo(app, "addEveryone")
        XCTAssertTrue(everyone.waitForExistence(timeout: 8), "Everyone is missing")
        everyone.tap()
        XCTAssertTrue(element(app, "rule.1").waitForExistence(timeout: 5), "the Everyone rule was not added")
        XCTAssertTrue(app.staticTexts["Everyone"].exists)
    }
}
