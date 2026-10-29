// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Sneakers_PAM
import Testing

struct HTTPServerProbeTests {
    private func response(status: Int = 200, headers: [String: String]) throws -> HTTPURLResponse {
        let url = try #require(URL(string: "https://one.example.org/livez"))
        return try #require(HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: headers))
    }

    @Test func readsTheVersionFromTheSneakersVersionHeader() throws {
        let version = try HTTPServerProbe.version(from: response(headers: ["Sneakers-Version": "v0.1.0"]))
        #expect(version == "v0.1.0")
    }

    @Test func theHeaderNameIsCaseInsensitive() throws {
        let version = try HTTPServerProbe.version(from: response(headers: ["sneakers-version": "v0.2.0"]))
        #expect(version == "v0.2.0")
    }

    @Test func aMissingHeaderMeansNoVersion() throws {
        #expect(try HTTPServerProbe.version(from: response(headers: [:])) == nil)
    }

    @Test func buildsTheProbeAddressesFromTheServerAddress() throws {
        let server = try ServerURL(input: "https://one.example.org:8443")
        #expect(HTTPServerProbe.url(path: "/livez", for: server)?
            .absoluteString == "https://one.example.org:8443/livez")
        #expect(HTTPServerProbe.url(path: "/healthz", for: server)?
            .absoluteString == "https://one.example.org:8443/healthz")
    }

    @Test func aHealthyAnswerWithAnOkStatusLooksLikeSneakers() {
        #expect(HTTPServerProbe.looksHealthy(status: 200, body: Data(#"{"status":"ok"}"#.utf8)))
    }

    @Test func anythingElseDoesNotLookLikeSneakers() {
        #expect(!HTTPServerProbe.looksHealthy(status: 404, body: Data(#"{"status":"ok"}"#.utf8)))
        #expect(!HTTPServerProbe.looksHealthy(status: 200, body: Data(#"{"status":"down"}"#.utf8)))
        #expect(!HTTPServerProbe.looksHealthy(status: 200, body: Data("<html></html>".utf8)))
        #expect(!HTTPServerProbe.looksHealthy(status: 200, body: Data()))
    }
}
