// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import os
import SwiftUI

/// The app's navigation shell: a tab bar on iPhone that becomes a sidebar on iPad. It opens on the sneaker loader,
/// then asks for a server if there is none, then for a sign-in. The tabs only exist once the active server has a
/// confirmed session.
struct RootView: View {
    private static let logger = Logger(subsystem: "com.therabbithole.app.apple.sneakers-pam", category: "shell")

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ServerRegistry.self) private var registry
    @Environment(SessionManager.self) private var sessions
    @Environment(AppLockModel.self) private var lock
    @State private var selection = AppSection.initial
    @State private var showsLoader = true
    @State private var checkedServers: Set<UUID> = []

    var body: some View {
        ZStack {
            if showsLoader {
                SplashView()
                    .transition(.opacity)
            } else if let server = registry.active {
                content(for: server)
                    .transition(.opacity)
            } else {
                AddServerView()
                    .transition(.opacity)
            }
        }
        .overlay {
            if lock.isCovered {
                PrivacyCoverView()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                lock.becameActive(at: .now)
            case .inactive, .background:
                lock.movedToBackground(at: .now)
            @unknown default:
                break
            }
        }
        .onChange(of: sessions.interactiveSignIns) {
            lock.signedInJustNow()
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

    @ViewBuilder
    private func content(for server: ServerEntry) -> some View {
        if sessions.isSignedIn(server.id) {
            if lock.isLocked {
                LockView()
            } else if let setup = requiredSetup(for: server) {
                AuthenticatorSetupView(model: setup, onSignOut: {
                    Task { await sessions.signOut(server) }
                })
            } else {
                shell
            }
        } else if checkedServers.contains(server.id) {
            SignInView(model: sessions.makeSignInModel(for: server))
                .id(server.id)
        } else {
            RestoringView()
                .task(id: server.id) {
                    let result = await sessions.restore(server)
                    Self.logger.debug("session restore: \(String(describing: result), privacy: .public)")
                    checkedServers.insert(server.id)
                }
        }
    }

    /// The setup steps when the server will not let this session do anything until a second factor exists.
    private func requiredSetup(for server: ServerEntry) -> AuthenticatorSetupModel? {
        guard sessions.session(for: server.id)?.enrolmentRequired == true else { return nil }
        return sessions.makeAuthenticatorSetupModel(for: server)
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

/// Shown for a moment while the app asks the server whether a saved session is still good.
private struct RestoringView: View {
    var body: some View {
        ZStack {
            Color("LaunchBackground").ignoresSafeArea()
            ProgressView()
        }
    }
}

#Preview {
    RootView()
        .environment(ServerRegistry(store: UserDefaultsServerStore(), probe: HTTPServerProbe(), policy: .current))
        .environment(SessionManager(auth: HTTPAuthService(), store: KeychainSessionStore()))
        .environment(AppLockModel(authenticator: LocalAuthenticator(), settings: UserDefaultsLockSettings()))
}
