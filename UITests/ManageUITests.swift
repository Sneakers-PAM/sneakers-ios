// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import XCTest

// Home, browsing and a secret's fields, run against the made-up vault a debug build uses for `-uiTestingSignedIn`.

/// Editing, history, rotation, retiring, creating and moving, on the demo vault.
final class ManageUITests: VaultUITestCase {
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
        let existing = (username.value as? String) ?? ""
        username.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count))
        username.typeText("bob")
        element(app, "editSave").tap()

        XCTAssertTrue(app.staticTexts["bob"].waitForExistence(timeout: 8), "the new value did not show")
    }

    @MainActor
    func testTheHistoryListsVersionsAndAnOldValueCanBeRevealedAndRestored() {
        let app = launchSignedIn()
        openDemoSecret(app)

        let history = scrollTo(app, "history")
        XCTAssertTrue(history.waitForExistence(timeout: 8), "the History link is missing")
        tapWhenSettled(history)

        let first = element(app, "version.1")
        XCTAssertTrue(first.waitForExistence(timeout: 8), "the versions are missing")
        XCTAssertTrue(element(app, "version.2").exists)
        tapWhenSettled(first)

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
    func testANewFolderCanBeMadeInsideAFolder() {
        let app = launchSignedIn()
        openFolders(app)
        openFolder(app, "Apps")

        let actions = element(app, "folderActions")
        XCTAssertTrue(actions.waitForExistence(timeout: 8), "the folder menu is missing")
        actions.tap()
        let newFolder = element(app, "newFolder")
        XCTAssertTrue(newFolder.waitForExistence(timeout: 5), "New folder is missing")
        newFolder.tap()

        let name = element(app, "folderName")
        XCTAssertTrue(name.waitForExistence(timeout: 5), "the name field is missing")
        name.tap()
        name.typeText("Lab")
        element(app, "folderNameSave").tap()

        XCTAssertTrue(element(app, "folder.Lab").waitForExistence(timeout: 8), "the new folder is not listed")
    }

    @MainActor
    func testANewSecretCanBeMadeInAFolder() {
        let app = launchSignedIn()
        openFolders(app)
        openFolder(app, "Apps")

        element(app, "folderActions").tap()
        let newSecret = element(app, "newSecret")
        XCTAssertTrue(newSecret.waitForExistence(timeout: 5), "New secret is missing")
        newSecret.tap()

        let name = element(app, "newSecretName")
        XCTAssertTrue(name.waitForExistence(timeout: 8), "the name field is missing")
        name.tap()
        name.typeText("Vendor login")
        let username = app.textFields["Username"]
        username.tap()
        username.typeText("bob")
        let password = app.secureTextFields["Password"]
        password.tap()
        password.typeText("hunter2")
        element(app, "newSecretCreate").tap()

        XCTAssertTrue(element(app, "secret.Vendor login").waitForExistence(timeout: 8), "the secret is not listed")
    }

    @MainActor
    func testASecretCanBeMovedToAnotherFolder() {
        let app = launchSignedIn()
        openDemoSecret(app)

        let move = element(app, "moveSecret")
        XCTAssertTrue(move.waitForExistence(timeout: 8), "the Move button is missing")
        move.tap()
        let picker = element(app, "moveDestination")
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "the destination is missing")
        picker.tap()
        let platform = app.buttons["Platform"].firstMatch
        XCTAssertTrue(platform.waitForExistence(timeout: 5), "the folder choice is missing")
        platform.tap()
        let confirm = element(app, "moveConfirm")
        XCTAssertTrue(confirm.isEnabled, "Move should be ready once a folder is chosen")
        confirm.tap()

        XCTAssertFalse(element(app, "moveConfirm").waitForExistence(timeout: 3), "the move screen did not close")
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
}
