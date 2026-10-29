// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Sneakers_PAM
import Testing

struct AddServerOutcomeMessageTests {
    private let entry = ServerEntry(id: UUID(), url: ServerURL.fixture, addedAt: Date(timeIntervalSince1970: 0))

    @Test func successesHaveNothingToSay() {
        #expect(AddServerOutcome.added(entry).message == nil)
        #expect(AddServerOutcome.addedUnverified(entry).message == nil)
        #expect(AddServerOutcome.alreadyAdded(entry).message == nil)
    }

    @Test func eachBadAddressSaysWhatIsWrong() {
        #expect(AddServerOutcome.invalidAddress(.empty).message == "Enter your server's address.")
        #expect(AddServerOutcome.invalidAddress(.notSecure).message
            == "The address must use https. The app never connects without TLS.")
        #expect(AddServerOutcome.invalidAddress(.malformed).message == "That doesn't look like a server address.")
        #expect(AddServerOutcome.invalidAddress(.hasCredentials).message
            == "Leave the username and password out of the address.")
    }

    @Test func aServerThatCannotBeReachedSaysSo() {
        #expect(AddServerOutcome.unreachable
            .message == "Couldn't reach that server. Check the address and your connection.")
    }

    @Test func somethingElseOnTheAddressSaysSo() {
        #expect(AddServerOutcome.notASneakersServer.message == "That address answered, but not as a Sneakers server.")
    }

    @Test func versionProblemsNameTheVersionAndWhoNeedsTheUpdate() {
        let version = ServerVersion(major: 0, minor: 0, patch: 9)
        #expect(AddServerOutcome.serverTooOld(version).message
            == "This server runs 0.0.9 and needs an update before this app can use it.")
        #expect(AddServerOutcome.appTooOld(ServerVersion(major: 9, minor: 1, patch: 0)).message
            == "This server runs 9.1.0, which is newer than this app supports. Update the app.")
    }
}

extension ServerURL {
    static var fixture: ServerURL {
        // The address is a constant in the tests, so parsing cannot fail.
        // swiftlint:disable:next force_try
        try! ServerURL(input: "one.example.org")
    }
}
