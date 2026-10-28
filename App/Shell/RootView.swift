// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import os
import SwiftUI

/// The app's navigation shell: a tab bar on iPhone that becomes a sidebar on iPad.
struct RootView: View {
    private static let logger = Logger(subsystem: "com.therabbithole.app.apple.sneakers-pam", category: "shell")

    @State private var selection = AppSection.initial

    var body: some View {
        TabView(selection: $selection) {
            ForEach(AppSection.allCases) { section in
                Tab(section.title, systemImage: section.systemImage, value: section) {
                    SectionPlaceholderView(section: section)
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .onChange(of: selection) { _, newSection in
            Self.logger.debug("section selected: \(newSection.rawValue, privacy: .public)")
        }
    }
}

#Preview {
    RootView()
}
