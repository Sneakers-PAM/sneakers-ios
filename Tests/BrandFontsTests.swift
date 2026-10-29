// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

@testable import Sneakers_PAM
import Testing
import UIKit

struct BrandFontsTests {
    @Test func everyFontFileIsBundledAsADataAsset() {
        for name in BrandFonts.assetNames {
            #expect(NSDataAsset(name: name) != nil, "missing data asset \(name)")
        }
    }

    @Test func everyLicenceTextIsBundledAlongsideTheFonts() {
        for name in BrandFonts.licenceAssetNames {
            #expect(NSDataAsset(name: name) != nil, "missing licence \(name)")
        }
    }

    @Test func registeringMakesEveryStyleAvailableByName() {
        let failures = BrandFonts.registerAll()

        #expect(failures.isEmpty)
        for name in BrandFonts.styleNames {
            #expect(UIFont(name: name, size: 17) != nil, "font \(name) did not register")
        }
    }

    @Test func registeringTwiceIsHarmless() {
        _ = BrandFonts.registerAll()
        #expect(BrandFonts.registerAll().isEmpty)
    }

    @Test func theTypeScaleFollowsTheLacesHandoff() {
        #expect(LacesTextStyle.display.size == 40)
        #expect(LacesTextStyle.title.size == 32)
        #expect(LacesTextStyle.heading.size == 22)
        #expect(LacesTextStyle.subheading.size == 18)
        #expect(LacesTextStyle.bodyLarge.size == 17)
        #expect(LacesTextStyle.body.size == 15)
        #expect(LacesTextStyle.small.size == 13)
    }

    @Test func titlesUseBricolageAndTextUsesAtkinsonAndValuesUseJetBrainsMono() {
        #expect(LacesTextStyle.title.fontName.hasPrefix("BricolageGrotesque"))
        #expect(LacesTextStyle.heading.fontName.hasPrefix("BricolageGrotesque"))
        #expect(LacesTextStyle.body.fontName.hasPrefix("AtkinsonHyperlegible"))
        #expect(LacesTextStyle.subheading.fontName.hasPrefix("AtkinsonHyperlegible"))
        #expect(LacesTextStyle.mono.fontName.hasPrefix("JetBrainsMono"))
    }

    @Test func everyStyleUsesAFontThatRegisters() {
        _ = BrandFonts.registerAll()
        for style in LacesTextStyle.allCases {
            #expect(UIFont(name: style.fontName, size: style.size) != nil, "style \(style) has no font")
        }
    }
}
