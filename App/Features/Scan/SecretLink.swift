// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// The address a secret's QR code points at. It names the secret and nothing else: no value, no access.
/// A link only counts when it is on the signed-in server, so a code for any other site is never followed.
nonisolated enum SecretLink {
    private static let idCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))

    static func url(for secretID: String, on server: ServerURL) -> URL? {
        server.origin.appendingPathComponent("secret").appendingPathComponent(secretID)
    }

    static func secretID(in text: String, on server: ServerURL) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmed),
              components.scheme?.lowercased() == "https",
              components.host?.lowercased() == server.host,
              (components.port == 443 ? nil : components.port) == server.port
        else { return nil }

        let parts = components.path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3, parts[0].isEmpty, parts[1] == "secret", isValid(id: parts[2]) else { return nil }
        return parts[2]
    }

    private static func isValid(id: String) -> Bool {
        !id.isEmpty && id.unicodeScalars.allSatisfy(idCharacters.contains)
    }
}
