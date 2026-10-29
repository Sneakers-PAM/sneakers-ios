// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

@testable import Sneakers_PAM
import Testing

struct SecretFormatTests {
    @Test func aKeyIsShownInGroupsOfFour() {
        #expect(SecretFormat.grouped("JBSWY3DPEHPK3PXP") == "JBSW Y3DP EHPK 3PXP")
    }

    @Test func aKeyThatDoesNotDivideEvenlyKeepsItsLastShortGroup() {
        #expect(SecretFormat.grouped("ABCDEF") == "ABCD EF")
    }

    @Test func aShortKeyIsLeftAlone() {
        #expect(SecretFormat.grouped("ABC") == "ABC")
        #expect(SecretFormat.grouped("") == "")
    }

    @Test func groupingNeverChangesTheKeyItself() {
        let key = "JBSWY3DPEHPK3PXP"
        #expect(SecretFormat.grouped(key).filter { $0 != " " } == key)
    }
}
