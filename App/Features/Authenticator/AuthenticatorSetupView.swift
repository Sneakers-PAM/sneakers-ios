// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import SwiftUI
import UniformTypeIdentifiers

/// Walks the person through setting up an authenticator app: scan the code, then type the code it shows.
/// When the server requires a second factor there is no way out except signing out.
struct AuthenticatorSetupView: View {
    let model: AuthenticatorSetupModel
    var onCancel: (() -> Void)?
    var onSignOut: (() -> Void)?

    @Environment(\.openURL) private var openURL
    @State private var code = ""
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                switch model.step {
                case .preparing:
                    ProgressView()
                        .frame(maxWidth: .infinity)
                case .failed:
                    retry
                case let .scan(enrollment):
                    scan(enrollment)
                }
                if let message = model.message {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("setupMessage")
                }
                if let onSignOut {
                    Button("Sign out", role: .destructive, action: onSignOut)
                        .font(.subheadline)
                        .accessibilityIdentifier("setupSignOut")
                }
            }
            .padding(24)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color("LaunchBackground").ignoresSafeArea())
        .toolbar {
            if let onCancel {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .accessibilityIdentifier("cancelSetup")
                }
            }
        }
        .task {
            if case .preparing = model.step {
                await model.start()
            }
        }
        .onChange(of: model.isEnrolled) { _, enrolled in
            if enrolled {
                onCancel?()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Set up an authenticator app")
                .lacesFont(.title)
                .tracking(-0.6)
                .accessibilityAddTraits(.isHeader)
            Text("Your account needs a second step when you sign in.")
                .lacesFont(.bodyLarge)
                .foregroundStyle(.secondary)
            Text("An authenticator app makes a new 6-digit code every 30 seconds.")
                .lacesFont(.bodyLarge)
                .foregroundStyle(.secondary)
        }
    }

    private var retry: some View {
        Button("Try again") {
            Task { await model.start() }
        }
        .buttonStyle(.borderedProminent)
        .tint(Color("LacesInk"))
    }

    private func scan(_ enrollment: AuthenticatorEnrollment) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("1. Scan this code with your authenticator app.")
                .font(.headline)
            qr(enrollment)
            Button("Open in my authenticator app", systemImage: "arrow.up.right.square") {
                if let url = URL(string: enrollment.otpauthURI) {
                    openURL(url)
                }
            }
            .font(.subheadline)
            manualKey(enrollment)
            Text("2. Enter the 6-digit code it shows.")
                .font(.headline)
            CodeEntryView(code: $code)
            Button {
                Task { await model.confirm(code: code) }
            } label: {
                HStack {
                    if model.isWorking {
                        ProgressView()
                    }
                    Text("Verify and turn on")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color("LacesInk"))
            .disabled(code.count != 6 || model.isWorking)
            .accessibilityIdentifier("confirmSetup")
        }
    }

    @ViewBuilder
    private func qr(_ enrollment: AuthenticatorEnrollment) -> some View {
        if let image = QRCode.image(for: enrollment.otpauthURI, side: 220) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 220, height: 220)
                .padding(12)
                .background(.white, in: RoundedRectangle(cornerRadius: 12))
                .frame(maxWidth: .infinity)
                .accessibilityLabel("QR code for your authenticator app")
        }
    }

    private func manualKey(_ enrollment: AuthenticatorEnrollment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Or type this key into the app by hand:")
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack {
                Text(SecretFormat.grouped(enrollment.secret))
                    .lacesFont(.mono)
                    .textSelection(.enabled)
                Spacer()
                Button(copied ? "Copied" : "Copy") {
                    copy(enrollment.secret)
                }
                .font(.subheadline.weight(.semibold))
            }
            .padding(12)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    /// The key stays on this device and leaves the clipboard after a minute.
    private func copy(_ secret: String) {
        let expiry = Date().addingTimeInterval(60)
        UIPasteboard.general.setItems(
            [[UTType.plainText.identifier: secret]],
            options: [.expirationDate: expiry, .localOnly: true]
        )
        copied = true
    }
}
