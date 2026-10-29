// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

@testable import Sneakers_PAM
import Testing

struct SneakerLoaderProgressTests {
    private func isClose(_ value: Double, _ expected: Double) -> Bool {
        abs(value - expected) < 1e-9
    }

    @Test func startsEmpty() {
        let state = SneakerLoaderProgress(progress: 0)
        #expect(isClose(state.sole, 0))
        #expect(isClose(state.body, 0))
        #expect(isClose(state.lace, 0))
        #expect(isClose(state.hole, 0))
    }

    @Test func endsFull() {
        let state = SneakerLoaderProgress(progress: 1)
        #expect(isClose(state.sole, 1))
        #expect(isClose(state.body, 1))
        #expect(isClose(state.lace, 1))
        #expect(isClose(state.hole, 1))
    }

    @Test func clampsProgressOutsideZeroToOne() {
        #expect(isClose(SneakerLoaderProgress(progress: -3).body, 0))
        #expect(isClose(SneakerLoaderProgress(progress: 9).body, 1))
    }

    @Test func soleFillsFirst() {
        #expect(isClose(SneakerLoaderProgress(progress: 0.22).sole, 1))
        #expect(isClose(SneakerLoaderProgress(progress: 0.15).body, 0))
    }

    @Test func bodyFinishesBeforeLacesStart() {
        #expect(isClose(SneakerLoaderProgress(progress: 0.82).body, 1))
        #expect(isClose(SneakerLoaderProgress(progress: 0.78).lace, 0))
    }

    @Test func inkRisesFromSoleLineToTopOfBody() {
        #expect(isClose(SneakerLoaderProgress(progress: 0).inkLevel, 48))
        #expect(isClose(SneakerLoaderProgress(progress: 1).inkLevel, 12))
    }

    @Test func lacesDrawOneAfterAnother() {
        let state = SneakerLoaderProgress(progress: 0.78 + 0.22 / 3)
        #expect(isClose(state.laceProgress(at: 0), 1))
        #expect(isClose(state.laceProgress(at: 1), 0))
        #expect(isClose(state.laceProgress(at: 2), 0))
    }

    @Test func totalTimeIsTheDelayPlusTheAnimation() {
        #expect(isClose(SneakerLoaderProgress.total, 2.05))
    }

    @Test func progressAfterTheDelayRunsFromZeroToOne() {
        #expect(isClose(SneakerLoaderProgress.progress(elapsed: 0), 0))
        #expect(isClose(SneakerLoaderProgress.progress(elapsed: 0.25), 0))
        #expect(isClose(SneakerLoaderProgress.progress(elapsed: 0.25 + 0.9), 0.5))
        #expect(isClose(SneakerLoaderProgress.progress(elapsed: 5), 1))
    }
}
