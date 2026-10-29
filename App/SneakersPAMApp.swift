// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

@main
struct SneakersPAMApp: App {
    @State private var registry = ServerRegistry.live()
    @State private var sessions = SessionManager.live()
    @State private var lock = AppLockModel.live()

    init() {
        BrandFonts.registerAll()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(registry)
                .environment(sessions)
                .environment(lock)
        }
    }
}
