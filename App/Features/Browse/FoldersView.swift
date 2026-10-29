// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

/// Folders: the folder tree, the secrets in a folder and one secret. Three columns on an iPad, a stack on an iPhone.
struct FoldersView: View {
    @Environment(VaultAccess.self) private var access
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var model = FoldersModel()
    @State private var folderID: String?
    @State private var secretID: String?
    @State private var visibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $visibility) {
            sidebar
                .navigationTitle("Folders")
                .toolbar { AccountToolbarButton() }
        } content: {
            if let folderID {
                SecretListView(folderID: folderID, selection: $secretID)
                    .id(folderID)
            } else {
                ContentUnavailableView("Pick a folder", systemImage: "folder")
            }
        } detail: {
            if let secretID {
                NavigationStack {
                    SecretDetailView(secretID: secretID, title: "Secret")
                }
                .id(secretID)
            } else {
                ContentUnavailableView("Pick a secret", systemImage: "key")
            }
        }
        .task { await model.load(access) }
        .onChange(of: folderID) {
            secretID = nil
            if sizeClass == .regular {
                visibility = .doubleColumn
            }
        }
    }

    @ViewBuilder
    private var sidebar: some View {
        if !model.hasLoaded {
            if let message = model.message {
                ContentUnavailableView {
                    Label("Couldn't load folders", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try again") { Task { await model.load(access) } }
                        .accessibilityIdentifier("foldersRetry")
                }
            } else {
                SneakerLoaderView(size: 96)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("foldersLoading")
            }
        } else if model.tree.nodes().isEmpty {
            ContentUnavailableView(
                "No folders",
                systemImage: "folder",
                description: Text("Nothing has been shared with you yet.")
            )
        } else {
            List(model.tree.nodes(), children: \.children, selection: $folderID) { node in
                Label(node.name, systemImage: "folder")
                    .tag(node.id)
                    .accessibilityIdentifier("folder.\(node.name)")
            }
            .refreshable { await model.load(access) }
        }
    }
}
