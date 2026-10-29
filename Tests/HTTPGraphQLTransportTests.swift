// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Sneakers_PAM
import Testing

// swiftlint:disable static_over_final_class
/// Answers every request after a short wait, so a test can cancel the caller while the request is in flight.
private final class SlowAnswer: URLProtocol, @unchecked Sendable {
    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let body = Data(#"{"data":{"ok":true}}"#.utf8)
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        else { return }
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            self.client?.urlProtocol(self, didLoad: body)
            self.client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}

// swiftlint:enable static_over_final_class

struct HTTPGraphQLTransportTests {
    private func transport() -> HTTPGraphQLTransport {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SlowAnswer.self]
        return HTTPGraphQLTransport(session: URLSession(configuration: configuration))
    }

    @Test func aRequestFinishesEvenWhenTheScreenThatAskedForItGoesAway() async throws {
        let transport = transport()
        let context = ServerContext.fixture
        let operation = GraphQLOperation(name: "Q", query: "query Q { ok }", variables: [:])
        let asking = Task { try await transport.execute(operation, in: context) }
        try await Task.sleep(for: .milliseconds(50))
        asking.cancel()

        let data = try await asking.value
        #expect(String(data: data, encoding: .utf8) == #"{"ok":true}"#)
    }
}
