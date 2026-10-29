// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

/// A short message after a copy or a refused reveal. It goes away on its own.
struct CopyNotice: View {
    @Environment(RevealCoordinator.self) private var reveal

    var body: some View {
        if let notice = reveal.notice {
            Text(notice)
                .font(.footnote)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.thinMaterial, in: Capsule())
                .padding(.bottom, 8)
                .transition(.opacity)
                .accessibilityIdentifier("notice")
                .task(id: notice) {
                    // A task cancelled by a redraw must not clear a notice nobody has had time to read.
                    guard await (try? Task.sleep(for: .seconds(4))) != nil else { return }
                    reveal.clearNotice()
                }
        }
    }
}
