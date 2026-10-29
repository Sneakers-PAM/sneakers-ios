// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

extension ServerVersion {
    nonisolated var text: String {
        "\(major).\(minor).\(patch)"
    }
}

extension AddServerOutcome {
    /// What to tell the person when the server could not be added. Nothing for a success.
    nonisolated var message: String? {
        switch self {
        case .added, .addedUnverified, .alreadyAdded:
            nil
        case let .invalidAddress(failure):
            Self.message(for: failure)
        case .unreachable:
            "Couldn't reach that server. Check the address and your connection."
        case .notASneakersServer:
            "That address answered, but not as a Sneakers server."
        case let .serverTooOld(version):
            "This server runs \(version.text) and needs an update before this app can use it."
        case let .appTooOld(version):
            "This server runs \(version.text), which is newer than this app supports. Update the app."
        }
    }

    private nonisolated static func message(for failure: ServerURL.Failure) -> String {
        switch failure {
        case .empty: "Enter your server's address."
        case .notSecure: "The address must use https. The app never connects without TLS."
        case .malformed: "That doesn't look like a server address."
        case .hasCredentials: "Leave the username and password out of the address."
        }
    }
}
