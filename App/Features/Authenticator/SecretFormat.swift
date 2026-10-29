// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

nonisolated enum SecretFormat {
    /// A key in groups of four, which is easier to read and type.
    static func grouped(_ secret: String) -> String {
        var groups: [String] = []
        var current = ""
        for character in secret {
            current.append(character)
            if current.count == 4 {
                groups.append(current)
                current = ""
            }
        }
        if !current.isEmpty {
            groups.append(current)
        }
        return groups.joined(separator: " ")
    }
}
