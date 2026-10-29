// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

/// Shown instead of the app while it is locked. Nothing from the server is in the view tree behind it. It says which
/// server is being unlocked, and the check is the phone's own Face ID or device passcode.
struct LockView: View {
    @Environment(AppLockModel.self) private var lock
    @Environment(ServerRegistry.self) private var registry

    private var serverName: String? {
        registry.active?.name
    }

    var body: some View {
        ZStack {
            Color("LaunchBackground").ignoresSafeArea()
            VStack(spacing: 18) {
                SneakerLoaderView(size: 96)
                Text("Locked")
                    .lacesFont(.title)
                    .accessibilityAddTraits(.isHeader)
                Text(LockContent.subtitle(serverName: serverName))
                    .lacesFont(.bodyLarge)
                    .multilineTextAlignment(.center)
                Text(LockContent.instruction)
                    .lacesFont(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if let message = lock.message {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("lockMessage")
                }
                Button {
                    unlock()
                } label: {
                    Label("Unlock", systemImage: "faceid")
                        .fontWeight(.semibold)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color("LacesInk"))
                .disabled(lock.isAuthenticating)
                .accessibilityIdentifier("unlockButton")
            }
            .padding(24)
        }
        .task { await lock.unlock(reason: LockContent.reason(serverName: serverName)) }
    }

    private func unlock() {
        let reason = LockContent.reason(serverName: serverName)
        Task { await lock.unlock(reason: reason) }
    }
}

/// Covers the app while it is out of sight, so the app switcher never shows a person's secrets.
struct PrivacyCoverView: View {
    var body: some View {
        ZStack {
            Color("LaunchBackground").ignoresSafeArea()
            SneakerLoaderView(size: 96)
        }
        .accessibilityHidden(true)
    }
}
