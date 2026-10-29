// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

/// The Account section: who the app is signed in to, sign out, the second factor, the lock setting and the servers
/// the app knows about.
struct AccountView: View {
    @Environment(ServerRegistry.self) private var registry
    @Environment(SessionManager.self) private var sessions
    @Environment(AppLockModel.self) private var lock
    @AppStorage("setup.reminder.dismissedAt") private var dismissedAt = 0.0
    @State private var isSigningOut = false
    @State private var showsSetup = false

    var body: some View {
        NavigationStack {
            List {
                if let server = registry.active {
                    Section {
                        if let name = sessions.session(for: server.id)?.username {
                            LabeledContent("Signed in as", value: name)
                        }
                        LabeledContent("Server", value: server.name)
                        LabeledContent("Release", value: server.version?.text ?? "Checked at sign-in")
                        Button("Sign out", role: .destructive) {
                            signOut(of: server)
                        }
                        .disabled(isSigningOut)
                        .accessibilityIdentifier("signOut")
                    } header: {
                        Text("Signed in")
                    }
                    secondFactorSection(for: server)
                }
                securitySection
                ServersSection()
            }
            .navigationTitle("Account")
        }
    }

    // MARK: Pieces

    @ViewBuilder
    private func secondFactorSection(for server: ServerEntry) -> some View {
        let recommended = sessions.session(for: server.id)?.setupRecommended ?? false
        let lastDismissed = dismissedAt > 0 ? Date(timeIntervalSince1970: dismissedAt) : nil
        if ReminderPolicy.standard.shows(setupRecommended: recommended, dismissedAt: lastDismissed, now: .now) {
            Section {
                Button("Set up an authenticator app", systemImage: "lock.shield") {
                    showsSetup = true
                }
                .accessibilityIdentifier("setUpAuthenticator")
                Button("Remind me later") {
                    dismissedAt = Date.now.timeIntervalSince1970
                }
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("remindLater")
            } header: {
                Text("Second factor")
            } footer: {
                Text("Protect your account with a second step at sign-in.")
            }
            .sheet(isPresented: $showsSetup) {
                if let model = sessions.makeAuthenticatorSetupModel(for: server) {
                    NavigationStack {
                        AuthenticatorSetupView(model: model, onCancel: { showsSetup = false })
                            .navigationBarTitleDisplayMode(.inline)
                    }
                }
            }
        }
    }

    private var securitySection: some View {
        Section {
            Toggle(LockContent.settingLabel, isOn: Binding(get: { lock.isEnabled }, set: lock.setEnabled))
                .accessibilityIdentifier("lockToggle")
        } header: {
            Text("Security")
        } footer: {
            if lock.deviceCannotLock {
                Text(
                    "This device has no passcode, so the app cannot lock. Set one in Settings to protect your secrets."
                )
            } else {
                Text("The app asks again after it has been out of sight for a short while.")
            }
        }
    }

    private func signOut(of server: ServerEntry) {
        isSigningOut = true
        Task {
            await sessions.signOut(server)
            isSigningOut = false
        }
    }
}

#Preview {
    AccountView()
        .environment(ServerRegistry(store: UserDefaultsServerStore(), probe: HTTPServerProbe(), policy: .current))
        .environment(SessionManager(auth: HTTPAuthService(), store: KeychainSessionStore()))
        .environment(AppLockModel(authenticator: LocalAuthenticator(), settings: UserDefaultsLockSettings()))
}
