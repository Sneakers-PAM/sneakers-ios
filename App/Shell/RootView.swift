// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import os
import SwiftUI

/// The app's navigation shell: a tab bar on iPhone that becomes a sidebar on iPad.
/// It opens on the sneaker loader, then asks for a server if there is none yet.
struct RootView: View {
    private static let logger = Logger(subsystem: "com.therabbithole.app.apple.sneakers-pam", category: "shell")

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(ServerRegistry.self) private var registry
    @State private var selection = AppSection.initial
    @State private var showsLoader = true

    var body: some View {
        ZStack {
            if showsLoader {
                SplashView()
                    .transition(.opacity)
            } else if registry.entries.isEmpty {
                AddServerView()
                    .transition(.opacity)
            } else {
                shell
                    .transition(.opacity)
            }
        }
        .task {
            if !reduceMotion {
                try? await Task.sleep(for: .seconds(SplashContent.totalVisible))
            }
            Self.logger.debug("loader finished")
            withAnimation(.easeInOut(duration: 0.25)) {
                showsLoader = false
            }
        }
    }

    private var shell: some View {
        TabView(selection: $selection) {
            ForEach(AppSection.allCases) { section in
                Tab(section.title, systemImage: section.systemImage, value: section) {
                    if section == .account {
                        AccountView()
                    } else {
                        SectionPlaceholderView(section: section)
                    }
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
        .environment(ServerRegistry(store: UserDefaultsServerStore(), probe: HTTPServerProbe(), policy: .current))
}
