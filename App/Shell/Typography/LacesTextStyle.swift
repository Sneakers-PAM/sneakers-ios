// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

/// The Laces type scale. Every style scales with the person's Dynamic Type setting, relative to the system style
/// it replaces.
nonisolated enum LacesTextStyle: CaseIterable {
    case wordmark
    case slogan
    case display
    case title
    case heading
    case subheading
    case bodyLarge
    case body
    case small
    case mono

    var size: CGFloat {
        switch self {
        case .wordmark: 30
        case .slogan: 22
        case .display: 40
        case .title: 32
        case .heading: 22
        case .subheading: 18
        case .bodyLarge: 17
        case .body: 15
        case .small: 13
        case .mono: 13
        }
    }

    var fontName: String {
        switch self {
        case .wordmark, .slogan, .display, .title: BrandFonts.displayExtraBold
        case .heading: BrandFonts.displayBold
        case .subheading: BrandFonts.textBold
        case .bodyLarge, .body, .small: BrandFonts.text
        case .mono: BrandFonts.mono
        }
    }

    var relativeTo: Font.TextStyle {
        switch self {
        case .wordmark, .display, .title: .largeTitle
        case .slogan, .heading: .title2
        case .subheading: .headline
        case .bodyLarge, .body: .body
        case .small, .mono: .footnote
        }
    }

    var font: Font {
        .custom(fontName, size: size, relativeTo: relativeTo)
    }
}

extension View {
    func lacesFont(_ style: LacesTextStyle) -> some View {
        font(style.font)
    }
}
