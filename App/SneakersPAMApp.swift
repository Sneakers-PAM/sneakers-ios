// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import SwiftUI
import UIKit

@main
struct SneakersPAMApp: App {
    @State private var registry: ServerRegistry
    @State private var sessions: SessionManager
    @State private var lock = AppLockModel.live()
    @State private var access: VaultAccess
    @State private var reveal: RevealCoordinator
    @State private var requests: RequestsModel
    @State private var capture: ScreenCaptureMonitor

    init() {
        BrandFonts.registerAll()
        let registry = ServerRegistry.live()
        let sessions = SessionManager.live()
        let vault = VaultEnvironment.make(registry: registry, sessions: sessions)
        _registry = State(initialValue: registry)
        _sessions = State(initialValue: sessions)
        _access = State(initialValue: vault.access)
        _reveal = State(initialValue: vault.reveal)
        _capture = State(initialValue: ScreenCaptureMonitor(
            access: vault.access,
            reporter: HTTPScreenCaptureReporter(),
            revealedSecretIDs: { [reveal = vault.reveal] in reveal.revealed.keys.map(\.secretID) },
            deviceName: UIDevice.current.model
        ))
        _requests = State(initialValue: RequestsModel(authenticator: VaultEnvironment.authenticator()))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(registry)
                .environment(sessions)
                .environment(lock)
                .environment(access)
                .environment(reveal)
                .environment(requests)
                .environment(capture)
        }
    }
}
