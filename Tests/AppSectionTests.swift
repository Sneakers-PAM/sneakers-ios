// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

@testable import Sneakers_PAM
import Testing

struct AppSectionTests {
    @Test func sectionsAppearInDesignOrder() {
        #expect(AppSection.allCases.map(\.title) == ["Home", "Folders", "Requests", "Approvals", "Account"])
    }

    @Test func everySectionHasASymbol() {
        for section in AppSection.allCases {
            #expect(!section.systemImage.isEmpty)
        }
    }

    @Test func sectionIdsAreUnique() {
        let ids = AppSection.allCases.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func launchesOnHome() {
        #expect(AppSection.initial == .home)
    }
}
