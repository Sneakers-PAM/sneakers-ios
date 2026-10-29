// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import os

/// Posts GraphQL to the gateway with the session cookie and the CSRF header. There is no shared cookie jar, so each
/// server's session stays separate. Only the operation name is logged, never its variables, which carry secret ids.
nonisolated struct HTTPGraphQLTransport: GraphQLTransport {
    private static let logger = Logger(subsystem: "com.therabbithole.app.apple.sneakers-pam", category: "vault")

    var session: URLSession = HTTPAuthService.makeSession()

    func execute(_ operation: GraphQLOperation, in context: ServerContext) async throws -> Data {
        let request = try Self.request(for: operation, in: context)
        let started = Date()
        do {
            let (body, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw VaultError.unexpected }
            let seconds = Date().timeIntervalSince(started)
            let status = http.statusCode
            let took = String(format: "%.2f", seconds)
            Self.logger.debug("graphql \(operation.name, privacy: .public): \(status) in \(took, privacy: .public)s")
            return try GraphQLResponse.parse(status: status, body: body)
        } catch let error as VaultError {
            Self.logger
                .info(
                    "graphql \(operation.name, privacy: .public) failed: \(String(describing: error), privacy: .public)"
                )
            throw error
        } catch {
            Self.logger.info("graphql \(operation.name, privacy: .public) could not reach the server")
            throw VaultError.unreachable
        }
    }

    static func request(for operation: GraphQLOperation, in context: ServerContext) throws -> URLRequest {
        var request = URLRequest(url: context.server.origin.appending(path: "/graphql"), timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("\(HTTPAuthService.cookieName)=\(context.session.cookieValue)", forHTTPHeaderField: "Cookie")
        request.setValue(context.session.csrfToken, forHTTPHeaderField: "X-CSRF-Token")
        request.httpShouldHandleCookies = false
        request.httpBody = try JSONEncoder().encode(Body(
            query: operation.query,
            operationName: operation.name,
            variables: operation.variables
        ))
        return request
    }

    private struct Body: Encodable {
        let query: String
        let operationName: String
        let variables: [String: GraphQLValue]
    }
}
