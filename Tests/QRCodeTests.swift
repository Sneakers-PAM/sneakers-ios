// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

@testable import Sneakers_PAM
import Testing
import UIKit

struct QRCodeTests {
    @Test func makesASquareImageForAnAuthenticatorAddress() throws {
        let image = try #require(QRCode.image(for: "otpauth://totp/Sneakers:alice?secret=JBSWY3DPEHPK3PXP", side: 240))
        #expect(image.size.width > 0)
        #expect(image.size.width == image.size.height)
    }

    @Test func theImageIsAtLeastTheRequestedSize() throws {
        let image = try #require(QRCode.image(for: "otpauth://totp/x?secret=ABC", side: 240))
        #expect(image.size.width >= 240)
    }

    @Test func aDifferentTextMakesADifferentImage() throws {
        let first = try #require(QRCode.image(for: "otpauth://totp/a?secret=AAAA", side: 200))
        let second = try #require(QRCode.image(for: "otpauth://totp/b?secret=BBBB", side: 200))
        #expect(first.pngData() != second.pngData())
    }

    @Test func nothingIsDrawnForEmptyText() {
        #expect(QRCode.image(for: "", side: 200) == nil)
    }
}
