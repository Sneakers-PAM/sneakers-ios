// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

/// Where a folder screen is pushed to.
struct FolderRoute: Hashable {
    let id: String
}

/// Folders: walk down through folders, which hold subfolders, secrets or both. On an iPad a secret opens beside the
/// list, and on an iPhone it opens on top of it.
struct FoldersView: View {
    @Environment(VaultAccess.self) private var access
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var model = FoldersModel()
    @State private var secretID: String?
    @State private var visibility = NavigationSplitViewVisibility.all

    var body: some View {
        Group {
            if sizeClass == .regular {
                split
            } else {
                stack
            }
        }
        .task { await model.load(access) }
    }

    private var stack: some View {
        NavigationStack {
            FolderContentView(folderID: nil, folders: model, selection: $secretID, pushesSecrets: true)
                .navigationDestination(for: FolderRoute.self) { route in
                    FolderContentView(folderID: route.id, folders: model, selection: $secretID, pushesSecrets: true)
                }
                .navigationDestination(for: SecretRoute.self) { route in
                    SecretDetailView(secretID: route.id, title: route.name)
                }
        }
    }

    private var split: some View {
        NavigationSplitView(columnVisibility: $visibility) {
            NavigationStack {
                FolderContentView(folderID: nil, folders: model, selection: $secretID, pushesSecrets: false)
                    .navigationDestination(for: FolderRoute.self) { route in
                        FolderContentView(
                            folderID: route.id, folders: model, selection: $secretID, pushesSecrets: false
                        )
                    }
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
        .onChange(of: secretID) {
            if secretID != nil {
                visibility = .detailOnly
            }
        }
    }
}
