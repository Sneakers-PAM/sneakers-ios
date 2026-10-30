// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Sneakers_PAM
import Testing

struct SecretLinkTests {
    private let server = ServerURL.vault

    @Test func buildsALinkThatHoldsOnlyTheSecretID() {
        let url = SecretLink.url(for: "abc-123", on: server)
        #expect(url?.absoluteString == "https://vault.example.org/secret/abc-123")
    }

    @Test func readsTheIDFromAScannedLink() {
        #expect(SecretLink.secretID(in: "https://vault.example.org/secret/abc-123", on: server) == "abc-123")
    }

    @Test func ignoresSurroundingSpacesAndTheHostCase() {
        #expect(SecretLink.secretID(in: "  https://Vault.Example.org/secret/s1\n", on: server) == "s1")
    }

    @Test func acceptsTheDefaultPortWrittenOut() {
        #expect(SecretLink.secretID(in: "https://vault.example.org:443/secret/s1", on: server) == "s1")
    }

    @Test func refusesALinkToAnotherServer() {
        #expect(SecretLink.secretID(in: "https://evil.example.com/secret/s1", on: server) == nil)
    }

    @Test func refusesAnotherPort() {
        #expect(SecretLink.secretID(in: "https://vault.example.org:8443/secret/s1", on: server) == nil)
    }

    @Test func refusesPlainHttp() {
        #expect(SecretLink.secretID(in: "http://vault.example.org/secret/s1", on: server) == nil)
    }

    @Test(arguments: [
        "https://vault.example.org/secret/",
        "https://vault.example.org/secret/s1/edit",
        "https://vault.example.org/folder/s1",
        "https://vault.example.org/secret/a b",
        "not a link",
        ""
    ])
    func refusesAnythingThatIsNotASecretLink(text: String) {
        #expect(SecretLink.secretID(in: text, on: server) == nil)
    }
}

extension ServerURL {
    static var vault: ServerURL {
        guard let url = try? ServerURL(input: "vault.example.org") else { preconditionFailure("a fixed address") }
        return url
    }
}
