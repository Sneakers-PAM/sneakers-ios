// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

/// The secrets in one folder, with a name filter and a swipe to copy the main value.
struct SecretListView: View {
    @Environment(VaultAccess.self) private var access
    @Environment(RevealCoordinator.self) private var reveal
    @State private var model: SecretListModel
    @Binding var selection: SecretRoute?

    init(folderID: String, selection: Binding<SecretRoute?>) {
        _model = State(initialValue: SecretListModel(folderID: folderID))
        _selection = selection
    }

    var body: some View {
        content
            .navigationTitle("Secrets")
            .searchable(text: $model.search, prompt: "Search this folder")
            .task { await model.load(access) }
            .safeAreaInset(edge: .bottom) { CopyNotice() }
    }

    @ViewBuilder
    private var content: some View {
        if !model.hasLoaded {
            if let message = model.message {
                ContentUnavailableView {
                    Label("Couldn't load secrets", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try again") { Task { await model.load(access) } }
                }
            } else {
                SneakerLoaderView(size: 96)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else if model.secrets.isEmpty {
            ContentUnavailableView("No secrets", systemImage: "key", description: Text("This folder is empty."))
        } else if model.visibleSecrets.isEmpty {
            ContentUnavailableView.search(text: model.search)
        } else {
            List(model.visibleSecrets, selection: $selection) { secret in
                row(secret)
                    .tag(SecretRoute(id: secret.id, name: secret.name))
            }
            .refreshable { await model.load(access) }
        }
    }

    private func row(_ secret: SecretSummary) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(secret.name)
                if secret.isReadable {
                    Text(secret.health.label)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if !secret.isReadable {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Locked")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("secret.\(secret.name)")
        .swipeActions(edge: .trailing) {
            if let key = model.primaryFieldKey(for: secret) {
                Button("Copy", systemImage: "doc.on.doc") {
                    Task { await reveal.copy(RevealKey(secretID: secret.id, fieldKey: key)) }
                }
                .tint(.accentColor)
            }
        }
    }
}
