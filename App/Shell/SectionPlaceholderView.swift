// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

/// Stands in for a section until its feature is built. Each section owns its navigation stack.
struct SectionPlaceholderView: View {
    let section: AppSection

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                section.title,
                systemImage: section.systemImage,
                description: Text("Nothing here yet.")
            )
            .navigationTitle(section.title)
        }
    }
}

#Preview {
    SectionPlaceholderView(section: .home)
}
