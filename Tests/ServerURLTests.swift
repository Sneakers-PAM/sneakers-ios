// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

@testable import Sneakers_PAM
import Testing

struct ServerURLTests {
    @Test func acceptsAnHTTPSAddress() throws {
        let url = try ServerURL(input: "https://sneakers.example.org")
        #expect(url.absoluteString == "https://sneakers.example.org")
    }

    @Test func addsHTTPSWhenTheSchemeIsMissing() throws {
        let url = try ServerURL(input: "sneakers.example.org")
        #expect(url.absoluteString == "https://sneakers.example.org")
    }

    @Test func trimsSpacesAndLowercasesTheHost() throws {
        let url = try ServerURL(input: "  HTTPS://Sneakers.Example.ORG/  ")
        #expect(url.absoluteString == "https://sneakers.example.org")
    }

    @Test func dropsThePathQueryAndFragment() throws {
        let url = try ServerURL(input: "https://sneakers.example.org/login?next=/a#top")
        #expect(url.absoluteString == "https://sneakers.example.org")
    }

    @Test func keepsANonDefaultPort() throws {
        let url = try ServerURL(input: "https://sneakers.example.org:8443")
        #expect(url.absoluteString == "https://sneakers.example.org:8443")
    }

    @Test func refusesPlainHTTP() {
        #expect(throws: ServerURL.Failure.notSecure) {
            try ServerURL(input: "http://sneakers.example.org")
        }
    }

    @Test func refusesAnEmptyAddress() {
        #expect(throws: ServerURL.Failure.empty) { try ServerURL(input: "   ") }
    }

    @Test func refusesAddressesWithCredentials() {
        #expect(throws: ServerURL.Failure.hasCredentials) {
            try ServerURL(input: "https://user:pass@sneakers.example.org")
        }
    }

    @Test func refusesAnAddressWithNoHost() {
        #expect(throws: ServerURL.Failure.malformed) { try ServerURL(input: "https://") }
        #expect(throws: ServerURL.Failure.malformed) { try ServerURL(input: "not a host") }
    }

    @Test func refusesOtherSchemes() {
        #expect(throws: ServerURL.Failure.notSecure) { try ServerURL(input: "ftp://sneakers.example.org") }
    }

    @Test func sameServerWrittenTwoWaysIsEqual() throws {
        let first = try ServerURL(input: "Sneakers.Example.org")
        let second = try ServerURL(input: "https://sneakers.example.org/")
        #expect(first == second)
    }
}
