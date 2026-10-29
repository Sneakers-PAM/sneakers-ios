// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

/// One level of the folder tree: its subfolders, then its own secrets, with a name filter and a swipe to copy a
/// secret's main value. The top level (no folder) lists only the folders.
struct FolderContentView: View {
    let folderID: String?
    let folders: FoldersModel
    @Binding var selection: String?
    /// True on an iPhone, where a secret is pushed. False beside the list, where it fills the detail column.
    let pushesSecrets: Bool

    @Environment(VaultAccess.self) private var access
    @Environment(RevealCoordinator.self) private var reveal
    @State private var secrets: SecretListModel?
    @State private var search = ""

    init(folderID: String?, folders: FoldersModel, selection: Binding<String?>, pushesSecrets: Bool) {
        self.folderID = folderID
        self.folders = folders
        self.pushesSecrets = pushesSecrets
        _selection = selection
        _secrets = State(initialValue: folderID.map(SecretListModel.init(folderID:)))
    }

    private var title: String {
        folderID.flatMap { folders.tree.folder($0)?.name } ?? "Folders"
    }

    private var subfolders: [Folder] {
        let all = folders.tree.children(of: folderID)
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? all : all.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    private var visibleSecrets: [SecretSummary] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let secrets else { return [] }
        return query.isEmpty ? secrets.secrets : secrets.secrets
            .filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        content
            .navigationTitle(title)
            .searchable(text: $search, prompt: "Search here")
            .toolbar {
                if folderID == nil {
                    AccountToolbarButton()
                }
            }
            .task { await secrets?.load(access) }
            .safeAreaInset(edge: .bottom) { CopyNotice() }
    }

    @ViewBuilder
    private var content: some View {
        if !folders.hasLoaded {
            if let message = folders.message {
                ContentUnavailableView {
                    Label("Couldn't load folders", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try again") { Task { await folders.load(access) } }
                        .accessibilityIdentifier("foldersRetry")
                }
            } else {
                SneakerLoaderView(size: 96)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("foldersLoading")
            }
        } else {
            list
        }
    }

    private var list: some View {
        List {
            if !subfolders.isEmpty {
                Section(folderID == nil ? "" : "Folders") {
                    ForEach(subfolders) { folder in
                        NavigationLink(value: FolderRoute(id: folder.id)) {
                            FolderRow(folder: folder)
                        }
                    }
                }
            }
            if let secrets {
                secretsSection(secrets)
            }
            if isEmpty {
                ContentUnavailableView(
                    "This folder is empty",
                    systemImage: "folder",
                    description: Text("No folders or secrets here.")
                )
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("folderEmpty")
            }
        }
        .refreshable {
            await folders.load(access)
            await secrets?.load(access)
        }
    }

    private var isEmpty: Bool {
        guard let secrets else { return folders.tree.children(of: nil).isEmpty }
        return secrets.hasLoaded && secrets.secrets.isEmpty && folders.tree.children(of: folderID).isEmpty
    }

    @ViewBuilder
    private func secretsSection(_ model: SecretListModel) -> some View {
        if let message = model.message, !model.hasLoaded {
            Section("Secrets") {
                Text(message).foregroundStyle(.red)
                Button("Try again") { Task { await model.load(access) } }
            }
        } else if !model.hasLoaded {
            Section("Secrets") {
                ProgressView().frame(maxWidth: .infinity)
            }
        } else if !visibleSecrets.isEmpty {
            Section("Secrets") {
                ForEach(visibleSecrets) { secret in
                    secretRow(secret)
                        .swipeActions(edge: .trailing) { copyAction(secret, model) }
                }
            }
        }
    }

    @ViewBuilder
    private func secretRow(_ secret: SecretSummary) -> some View {
        if pushesSecrets {
            NavigationLink(value: SecretRoute(id: secret.id, name: secret.name)) {
                SecretRow(secret: secret)
            }
        } else {
            SecretRow(secret: secret)
                .contentShape(Rectangle())
                .onTapGesture { selection = secret.id }
                .accessibilityAddTraits(.isButton)
                .listRowBackground(selection == secret.id ? Color.accentColor.opacity(0.15) : nil)
        }
    }

    @ViewBuilder
    private func copyAction(_ secret: SecretSummary, _ model: SecretListModel) -> some View {
        if let key = model.primaryFieldKey(for: secret) {
            Button("Copy", systemImage: "doc.on.doc") {
                Task { await reveal.copy(RevealKey(secretID: secret.id, fieldKey: key)) }
            }
            .tint(.accentColor)
        }
    }
}

private struct FolderRow: View {
    let folder: Folder

    var body: some View {
        HStack {
            Label(folder.name, systemImage: "folder")
            Spacer()
            Text(folder.secretCountText)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("folder.\(folder.name)")
    }
}

private struct SecretRow: View {
    let secret: SecretSummary

    var body: some View {
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
    }
}
