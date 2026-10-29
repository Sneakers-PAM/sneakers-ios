// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

@main
struct SneakersPAMApp: App {
    @State private var registry = ServerRegistry.live()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(registry)
        }
    }
}
