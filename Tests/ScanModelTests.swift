// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Sneakers_PAM
import Testing

@MainActor
struct ScanModelTests {
    private let server = ServerURL.vault

    @Test func opensTheSecretNamedByAGoodLink() {
        let model = ScanModel(server: server)
        model.scanned("https://vault.example.org/secret/s1")
        #expect(model.openedSecretID == "s1")
        #expect(model.message == nil)
    }

    @Test func saysPlainlyWhenTheCodeIsNotForThisServer() {
        let model = ScanModel(server: server)
        model.scanned("https://other.example.com/secret/s1")
        #expect(model.openedSecretID == nil)
        #expect(model.message == ScanModel.wrongCodeMessage)
    }

    @Test func aLaterGoodScanClearsTheMessage() {
        let model = ScanModel(server: server)
        model.scanned("nonsense")
        model.scanned("https://vault.example.org/secret/s2")
        #expect(model.message == nil)
        #expect(model.openedSecretID == "s2")
    }

    @Test func startsOnALinkItWasOpenedWith() {
        let model = ScanModel(server: server, startingWith: "https://vault.example.org/secret/s3")
        #expect(model.openedSecretID == "s3")
    }

    @Test func pastedTextIsReadTheSameWay() {
        let model = ScanModel(server: server)
        model.pasted = "https://vault.example.org/secret/s4"
        model.openPasted()
        #expect(model.openedSecretID == "s4")
    }
}
