// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

/// One secret: its health, who has it checked out, and its fields with reveal and copy.
struct SecretDetailView: View {
    let secretID: String
    let title: String

    @Environment(VaultAccess.self) private var access
    @Environment(RevealCoordinator.self) private var reveal
    @State private var model: SecretDetailModel
    @State private var editing: EditSecretModel?
    @State private var moving: MoveModel?

    init(secretID: String, title: String) {
        self.secretID = secretID
        self.title = title
        _model = State(initialValue: SecretDetailModel(secretID: secretID))
    }

    private func openMove() async {
        guard let detail = model.loadedDetail, let folderID = detail.summary.folderId,
              let folders = try? await access.perform({ try await access.service.folders($0) })
        else { return }
        let subject = MoveModel.Subject.secret(id: secretID, name: detail.summary.name, folderID: folderID)
        moving = MoveModel(subject: subject, tree: FolderTree(folders: folders))
    }

    private var userID: String {
        (try? access.context().session.userID) ?? ""
    }

    private var loadedName: String? {
        if case let .loaded(detail) = model.phase {
            detail.summary.name
        } else {
            nil
        }
    }

    var body: some View {
        content
            .navigationTitle(loadedName ?? title)
            .navigationBarTitleDisplayMode(.inline)
            .task { await model.load(access) }
            .navigationDestination(for: HistoryRoute.self) { route in
                HistoryView(secretID: route.secretID, labels: model.fieldLabels)
            }
            .toolbar {
                if model.canEdit {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Edit") { editing = model.makeEditModel() }
                            .accessibilityIdentifier("editSecret")
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button("Move", systemImage: "folder") { Task { await openMove() } }
                            .labelStyle(.iconOnly)
                            .accessibilityIdentifier("moveSecret")
                    }
                }
            }
            .sheet(item: $moving) { move in
                MoveView(model: move) { Task { await model.load(access) } }
            }
            .sheet(item: $editing) { draft in
                EditSecretView(model: draft) { Task { await model.load(access) } }
            }
            .safeAreaInset(edge: .bottom) { CopyNotice() }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading:
            SneakerLoaderView(size: 96)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .failed(message):
            ContentUnavailableView {
                Label("Couldn't load this secret", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try again") { Task { await model.load(access) } }
            }
        case let .loaded(detail):
            loaded(detail)
        }
    }

    private func loaded(_ detail: SecretDetail) -> some View {
        List {
            Section {
                if let path = detail.folderPath {
                    LabeledContent("Folder", value: path)
                }
            }
            if !detail.summary.isReadable {
                Section {
                    Label("You can see this secret exists but can't read it.", systemImage: "lock.fill")
                        .accessibilityIdentifier("noAccess")
                }
            } else {
                HeartbeatCard(model: model)
                RotationCard(model: model)
                leaseSection
                Section("Fields") {
                    ForEach(model.fieldRows) { row in
                        FieldRowView(secretID: secretID, row: row)
                    }
                }
                LifecycleCard(model: model)
                Section {
                    NavigationLink(value: HistoryRoute(secretID: secretID)) {
                        Label("History", systemImage: "clock.arrow.circlepath")
                    }
                    .accessibilityIdentifier("history")
                }
            }
            if let message = model.message {
                Section { Text(message).foregroundStyle(.red).accessibilityIdentifier("detailMessage") }
            }
        }
        .refreshable { await model.load(access) }
    }

    @ViewBuilder
    private var leaseSection: some View {
        let state = model.leaseState(userID: userID)
        if state != .free || model.canCheckOut {
            Section("Check out") {
                switch state {
                case .free:
                    Button("Check out") { Task { await model.checkOut(access) } }
                        .disabled(model.isWorking || !model.canCheckOut)
                        .accessibilityIdentifier("checkOut")
                case let .heldByMe(expires):
                    LabeledContent("Checked out to you", value: expires.map(Self.until) ?? "")
                    Button("Check in") { Task { await model.checkIn(access) } }
                        .disabled(model.isWorking)
                        .accessibilityIdentifier("checkIn")
                case .heldByOther:
                    Label("Someone else has this checked out.", systemImage: "person.fill.badge.minus")
                }
            }
        }
    }

    private static func until(_ date: Date) -> String {
        "until " + date.formatted(date: .omitted, time: .shortened)
    }
}

/// A field: a plain value copies as it is, and a sensitive one is revealed or copied through the server.
private struct FieldRowView: View {
    let secretID: String
    let row: FieldRow

    @Environment(RevealCoordinator.self) private var reveal

    private var key: RevealKey {
        RevealKey(secretID: secretID, fieldKey: row.key)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(row.label)
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack {
                value
                Spacer()
                actions
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("field.\(row.key)")
    }

    @ViewBuilder
    private var value: some View {
        if let plain = row.plainValue {
            FieldValueText(kind: row.kind, value: plain)
        } else if let shown = reveal.revealed[key] {
            FieldValueText(kind: row.kind == .multiline ? .multiline : .text, value: shown)
                .textSelection(.disabled)
                .accessibilityIdentifier("revealedValue")
        } else {
            Text(String(repeating: "\u{2022}", count: 10))
                .accessibilityLabel("Hidden")
        }
    }

    @ViewBuilder
    private var actions: some View {
        if let plain = row.plainValue {
            Button("Copy", systemImage: "doc.on.doc") { reveal.copyKnown(plain) }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .accessibilityIdentifier("copy.\(row.key)")
        } else if row.isSensitive {
            if reveal.revealed[key] != nil {
                Button("Hide", systemImage: "eye.slash") { reveal.hide(key) }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("hide.\(row.key)")
            } else {
                Button("Reveal", systemImage: "eye") { Task { await reveal.show(key) } }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("reveal.\(row.key)")
            }
            Button("Copy", systemImage: "doc.on.doc") { Task { await reveal.copy(key) } }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .accessibilityIdentifier("copy.\(row.key)")
        }
    }
}
