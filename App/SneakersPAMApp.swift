// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

@main
struct SneakersPAMApp: App {
    @State private var registry: ServerRegistry
    @State private var sessions: SessionManager
    @State private var lock = AppLockModel.live()
    @State private var access: VaultAccess
    @State private var reveal: RevealCoordinator

    init() {
        BrandFonts.registerAll()
        let registry = ServerRegistry.live()
        let sessions = SessionManager.live()
        let vault = VaultEnvironment.make(registry: registry, sessions: sessions)
        _registry = State(initialValue: registry)
        _sessions = State(initialValue: sessions)
        _access = State(initialValue: vault.access)
        _reveal = State(initialValue: vault.reveal)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(registry)
                .environment(sessions)
                .environment(lock)
                .environment(access)
                .environment(reveal)
        }
    }
}
