// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

/// Asks for a fresh second factor when the server wants one before it reveals a value.
struct StepUpView: View {
    @Environment(RevealCoordinator.self) private var reveal
    @State private var kind = SecondFactorKind.totp
    @State private var code = ""

    private var isWorking: Bool {
        reveal.stepUp?.isWorking == true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Code from", selection: $kind) {
                        Text("Authenticator").tag(SecondFactorKind.totp)
                        Text("Email").tag(SecondFactorKind.email)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("stepUpKind")
                    CodeEntryView(code: $code)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    if kind == .email {
                        Button("Send me a code") { Task { await reveal.sendStepUpEmail() } }
                            .accessibilityIdentifier("stepUpSendEmail")
                    }
                } footer: {
                    Text(reveal.stepUp?.message ?? "Enter a fresh 6-digit code to continue.")
                        .accessibilityIdentifier("stepUpMessage")
                }
                Section {
                    Button("Verify") { Task { await reveal.submitStepUp(code: code, kind: kind) } }
                        .disabled(code.count != 6 || isWorking)
                        .accessibilityIdentifier("stepUpVerify")
                }
            }
            .navigationTitle("Confirm it's you")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { reveal.cancelStepUp() }
                        .accessibilityIdentifier("stepUpCancel")
                }
            }
            .onChange(of: reveal.stepUp?.message) {
                if reveal.stepUp?.message != nil {
                    code = ""
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
