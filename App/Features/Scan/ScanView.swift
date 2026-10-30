// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

/// Scan a secret's QR code, or paste its link, and open that secret. The usual access checks apply once it opens.
struct ScanView: View {
    @State private var model: ScanModel
    @State private var path: [SecretRoute] = []
    @Environment(\.dismiss) private var dismiss

    init(server: ServerURL, link: String? = nil) {
        _model = State(initialValue: ScanModel(server: server, startingWith: link))
    }

    var body: some View {
        NavigationStack(path: $path) {
            Form {
                if CodeScanner.isAvailable {
                    Section {
                        CodeScanner { model.scanned($0) }
                            .frame(height: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .listRowInsets(EdgeInsets())
                            .accessibilityIdentifier("scanCamera")
                    }
                }
                Section("Or paste a link") {
                    TextField("https://", text: $model.pasted)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .accessibilityIdentifier("scanLink")
                    Button("Open") { model.openPasted() }
                        .disabled(model.pasted.isEmpty)
                        .accessibilityIdentifier("scanOpen")
                }
                if let message = model.message {
                    Section {
                        Text(message)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("scanMessage")
                    }
                }
            }
            .navigationTitle("Scan a secret")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .accessibilityIdentifier("scanClose")
                }
            }
            .navigationDestination(for: SecretRoute.self) { route in
                SecretDetailView(secretID: route.id, title: "Secret")
            }
            .onChange(of: model.openedSecretID, initial: true) {
                if let id = model.openedSecretID {
                    path = [SecretRoute(id: id, name: "Secret")]
                }
            }
        }
    }
}

/// The button that opens the scanner. It needs the signed-in server to know which links are its own.
struct ScanToolbarButton: ToolbarContent {
    @Binding var presenting: ScanRequest?
    let server: ServerURL?

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Scan", systemImage: "qrcode.viewfinder") {
                presenting = ScanRequest(link: nil)
            }
            .disabled(server == nil)
            .accessibilityIdentifier("scanButton")
        }
    }
}

/// What opens the scanner: a plain open, or a link the app was launched with.
struct ScanRequest: Identifiable {
    let id = UUID()
    let link: String?
}
