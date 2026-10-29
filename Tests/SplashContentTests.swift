// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

@testable import Sneakers_PAM
import Testing

struct SplashContentTests {
    @Test func wordmarkIsSneakersDotPam() {
        #expect(SplashContent.wordmark.start == "sneakers")
        #expect(SplashContent.wordmark.dot == "\u{00B7}")
        #expect(SplashContent.wordmark.end == "pam")
    }

    @Test func sloganIsTwoLinesWithATrademarkMark() {
        #expect(SplashContent.sloganLines == ["Tie it once.", "Tie it properly."])
        #expect(SplashContent.trademark == "\u{2122}")
    }

    @Test func footerNamesTheLicenceAndTheCopyrightHolder() {
        #expect(SplashContent.licenceLine == "Open source \u{00B7} Apache-2.0")
        #expect(SplashContent.copyrightLine == "\u{00A9} 2026 The Sneakers-PAM Authors")
        #expect(SplashContent.footerLines == [SplashContent.licenceLine, SplashContent.copyrightLine])
    }

    @Test func screenHoldsForAMomentAfterTheSneakerFills() {
        #expect(SplashContent.hold == 1.2)
        #expect(abs(SplashContent.totalVisible - (SneakerLoaderProgress.total + 1.2)) < 1e-9)
    }
}
