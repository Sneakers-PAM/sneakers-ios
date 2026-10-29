// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// The address of a Sneakers server, reduced to its origin: https, a host and an optional port.
/// Plain http is refused, because the app never talks to a server without TLS checks.
nonisolated struct ServerURL: Hashable, Codable, Sendable {
    enum Failure: Error, Equatable {
        case empty
        case notSecure
        case malformed
        case hasCredentials
    }

    let host: String
    let port: Int?

    var absoluteString: String {
        "https://\(host)" + (port.map { ":\($0)" } ?? "")
    }

    init(input: String) throws {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw Failure.empty }

        let text = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard let components = URLComponents(string: text) else { throw Failure.malformed }
        guard components.scheme?.lowercased() == "https" else { throw Failure.notSecure }
        guard components.user == nil, components.password == nil else { throw Failure.hasCredentials }
        guard let rawHost = components.host, Self.isValid(host: rawHost) else { throw Failure.malformed }

        host = rawHost.lowercased()
        port = components.port == 443 ? nil : components.port
    }

    init(from decoder: any Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        try self.init(input: text)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(absoluteString)
    }

    private static func isValid(host: String) -> Bool {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-."))
        return !host.isEmpty && host.unicodeScalars.allSatisfy(allowed.contains)
    }
}
