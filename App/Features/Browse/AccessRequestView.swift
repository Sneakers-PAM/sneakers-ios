// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

/// Asks for access to a secret I can see but not read.
struct AccessRequestView: View {
    @Bindable var model: AccessRequestModel

    @Environment(VaultAccess.self) private var access
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Why do you need it", text: $model.reason, axis: .vertical)
                        .accessibilityIdentifier("requestReason")
                } footer: {
                    Text("The people who can approve it will see this.")
                }
                if let message = model.message {
                    Section { Text(message).foregroundStyle(.red) }
                }
                if model.didSend {
                    Section {
                        Label("Request sent. You will see it under Requests.", systemImage: "checkmark.circle")
                            .accessibilityIdentifier("requestSent")
                    }
                }
            }
            .navigationTitle("Request access")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(model.didSend ? "Done" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") { Task { await model.send(access) } }
                        .disabled(!model.canSend)
                        .accessibilityIdentifier("requestSend")
                }
            }
        }
        .presentationDetents([.medium])
    }
}

extension AccessRequestModel: Identifiable {
    nonisolated var id: String {
        secretID
    }
}
