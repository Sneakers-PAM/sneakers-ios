// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// The words on the opening screen and how long they take, in one place so the brand copy is tested.
nonisolated enum SplashContent {
    static let wordmark = (start: "sneakers", dot: "\u{00B7}", end: "pam")
    static let sloganLines = ["Tie it once.", "Tie it properly."]
    static let trademark = "\u{2122}"
    static let licenceLine = "Open source \u{00B7} Apache-2.0"
    static let copyrightLine = "\u{00A9} 2026 The Sneakers-PAM Authors"
    static let footerLines = [licenceLine, copyrightLine]

    /// The text is on screen from the start. Once the sneaker has filled, the screen holds before the app opens.
    static let hold = 1.2
    static var totalVisible: Double {
        SneakerLoaderProgress.total + hold
    }
}
