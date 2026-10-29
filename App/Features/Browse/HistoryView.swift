// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

/// Where the history screen is pushed to.
struct HistoryRoute: Hashable {
    let secretID: String
}

/// Every saved version of a secret: who changed it, when, and what. An old value is read through the same audited
/// reveal as a current one, and a version can be made the current one again.
struct HistoryView: View {
    let secretID: String
    let labels: [String: String]

    @Environment(VaultAccess.self) private var access
    @Environment(RevealCoordinator.self) private var reveal
    @State private var model: HistoryModel

    init(secretID: String, labels: [String: String]) {
        self.secretID = secretID
        self.labels = labels
        _model = State(initialValue: HistoryModel(secretID: secretID))
    }

    var body: some View {
        content
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .task { await model.load(access) }
            .onChange(of: reveal.restoredCount) { Task { await model.load(access) } }
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
                Label("Couldn't load the history", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try again") { Task { await model.load(access) } }
            }
        case let .loaded(versions):
            List(versions) { version in
                VersionRow(
                    secretID: secretID, version: version, labels: labels, canRestore: model.canRestore(version)
                ) {
                    Task { await reveal.restore(secretID: secretID, versionNo: version.versionNo) }
                }
            }
            .accessibilityIdentifier("historyList")
            .refreshable { await model.load(access) }
        }
    }
}

private struct VersionRow: View {
    let secretID: String
    let version: SecretVersion
    let labels: [String: String]
    let canRestore: Bool
    let onRestore: () -> Void

    @State private var isOpen = false
    @State private var isConfirming = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                isOpen.toggle()
            } label: {
                header
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("version.\(version.versionNo)")
            if isOpen {
                ForEach(version.fieldKeys, id: \.self) { key in
                    OldValueRow(
                        key: RevealKey(secretID: secretID, fieldKey: key, versionNo: version.versionNo),
                        label: labels[key] ?? key
                    )
                }
                if canRestore {
                    restoreControls
                }
            }
        }
    }

    /// Restoring asks twice, in place: it makes this version the current one.
    @ViewBuilder
    private var restoreControls: some View {
        if isConfirming {
            Text("It becomes the current version, and the current one stays in the history.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack {
                Button("Restore version \(version.versionNo)", role: .destructive) {
                    isConfirming = false
                    onRestore()
                }
                .accessibilityIdentifier("restoreConfirm")
                Spacer()
                Button("Cancel") { isConfirming = false }
            }
            .buttonStyle(.bordered)
        } else {
            Button("Restore this version", systemImage: "arrow.uturn.backward") { isConfirming = true }
                .accessibilityIdentifier("restore.\(version.versionNo)")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("Version \(version.versionNo)").font(.headline)
                if version.active {
                    Text("Current")
                        .font(.caption.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.tint.opacity(0.2), in: Capsule())
                }
                Spacer()
                Image(systemName: isOpen ? "chevron.up" : "chevron.down").foregroundStyle(.secondary)
            }
            Text(version.summary(labels: labels))
                .font(.subheadline)
            Text(byline)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var byline: String {
        guard let date = version.createdAtDate else { return version.createdByName }
        return "\(version.createdByName), \(date.formatted(date: .abbreviated, time: .shortened))"
    }
}

/// One field of an old version, read only when asked.
private struct OldValueRow: View {
    let key: RevealKey
    let label: String

    @Environment(RevealCoordinator.self) private var reveal

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.footnote).foregroundStyle(.secondary)
                if let value = reveal.revealed[key] {
                    Text(value)
                        .font(.system(.body, design: .monospaced))
                        .accessibilityIdentifier("oldValue")
                } else {
                    Text(String(repeating: "\u{2022}", count: 10)).accessibilityLabel("Hidden")
                }
            }
            Spacer()
            if reveal.revealed[key] != nil {
                Button("Hide", systemImage: "eye.slash") { reveal.hide(key) }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
            } else {
                Button("Reveal", systemImage: "eye") { Task { await reveal.show(key) } }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("revealOld.\(key.fieldKey).\(key.versionNo ?? 0)")
            }
        }
    }
}
