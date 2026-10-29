// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

/// Asks for a server address, checks it, and saves it when it is a supported Sneakers server.
/// It is the first screen on a new install and the add sheet in Account.
struct AddServerView: View {
    @Environment(ServerRegistry.self) private var registry

    var onAdded: () -> Void = {}
    /// Set when the view is a sheet the person can leave. The first-launch screen has none, because the app
    /// needs a server before it can do anything.
    var onCancel: (() -> Void)?

    @State private var address = ""
    @State private var isChecking = false
    @State private var message: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add your server")
                        .font(.system(size: 32, weight: .heavy))
                        .tracking(-0.6)
                        .accessibilityAddTraits(.isHeader)
                    Text("Enter the address of your Sneakers server. You can add more than one later.")
                        .foregroundStyle(.secondary)
                }

                TextField("sneakers.example.org", text: $address)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .focused($isFocused)
                    .padding(14)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                    .onSubmit(check)
                    .accessibilityIdentifier("serverAddress")

                if let message {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("serverMessage")
                }

                Button(action: check) {
                    HStack {
                        if isChecking {
                            ProgressView()
                        }
                        Text(isChecking ? "Checking" : "Check and add")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color("LacesInk"))
                .disabled(address.trimmingCharacters(in: .whitespaces).isEmpty || isChecking)
                .accessibilityIdentifier("checkAndAdd")
            }
            .padding(24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color("LaunchBackground").ignoresSafeArea())
        .toolbar {
            if let onCancel {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .accessibilityIdentifier("cancelAddServer")
                }
            }
        }
    }

    private func check() {
        guard !isChecking else { return }
        isChecking = true
        message = nil
        Task {
            let outcome = await registry.add(input: address)
            isChecking = false
            message = outcome.message
            if outcome.message == nil {
                address = ""
                onAdded()
            }
        }
    }
}

#Preview {
    AddServerView()
        .environment(ServerRegistry(store: UserDefaultsServerStore(), probe: HTTPServerProbe(), policy: .current))
}
