// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// The timing and stage maths of the sneaker loader, kept apart from drawing so it can be tested.
/// The sole fills first, ink then rises through the body, and the keyhole and laces finish it.
nonisolated struct SneakerLoaderProgress {
    static let delay = 0.25
    static let duration = 1.8
    static var total: Double {
        delay + duration
    }

    /// Overall progress, from 0 to 1 over `duration` once `delay` has passed.
    static func progress(elapsed: Double) -> Double {
        clamp((elapsed - delay) / duration)
    }

    let progress: Double

    init(progress: Double) {
        self.progress = Self.clamp(progress)
    }

    var sole: Double {
        Self.ease(segment(0, 0.22))
    }

    var body: Double {
        Self.ease(segment(0.15, 0.82))
    }

    var lace: Double {
        segment(0.78, 1)
    }

    var hole: Double {
        segment(0.7, 0.85)
    }

    /// The y position of the ink surface in the 64 by 64 mark, from the sole line up to the top of the body.
    var inkLevel: Double {
        48 - (48 - 12) * body
    }

    /// Each of the three laces draws in turn.
    func laceProgress(at index: Int) -> Double {
        Self.clamp(lace * 3 - Double(index))
    }

    private func segment(_ start: Double, _ end: Double) -> Double {
        Self.clamp((progress - start) / (end - start))
    }

    private static func ease(_ value: Double) -> Double {
        1 - pow(1 - value, 3)
    }

    private static func clamp(_ value: Double) -> Double {
        max(0, min(1, value))
    }
}
