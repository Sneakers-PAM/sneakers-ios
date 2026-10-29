// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

/// Keeps a requests screen fresh: loads when it appears and again every twenty seconds while it is on screen.
private struct KeepFresh: ViewModifier {
    let model: RequestsModel
    @Environment(VaultAccess.self) private var access

    func body(content: Content) -> some View {
        content
            .task {
                while !Task.isCancelled {
                    await model.load(access)
                    guard await (try? Task.sleep(for: .seconds(20))) != nil else { return }
                }
            }
            .refreshable { await model.load(access) }
    }
}

/// What I asked for: open requests and reveals still waiting, then what was decided.
struct RequestsView: View {
    @Environment(RequestsModel.self) private var model

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Requests")
                .toolbar { AccountToolbarButton() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading:
            SneakerLoaderView(size: 96)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .modifier(KeepFresh(model: model))
        case let .failed(message):
            ContentUnavailableView {
                Label("Couldn't load requests", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            }
            .modifier(KeepFresh(model: model))
        case .loaded:
            list.modifier(KeepFresh(model: model))
        }
    }

    private var list: some View {
        List {
            if model.board.open.isEmpty, model.myUses.isEmpty, model.board.history.filter(\.mine).isEmpty {
                ContentUnavailableView(
                    "Nothing asked for",
                    systemImage: "tray",
                    description: Text("Ask for access from a locked secret.")
                )
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("requestsEmpty")
            }
            if !model.board.open.isEmpty || !model.myUses.isEmpty {
                Section("Waiting") {
                    ForEach(model.board.open) { RequestCard(row: $0) }
                    ForEach(model.myUses) { UseCard(use: $0) { EmptyView() } }
                }
            }
            let decided = model.board.history.filter(\.mine)
            if !decided.isEmpty {
                Section("Decided") {
                    ForEach(decided) { RequestCard(row: $0) }
                }
            }
        }
    }
}

/// What waits on me: requests and reveals to approve or deny, each confirmed with the device first.
struct ApprovalsView: View {
    @Environment(RequestsModel.self) private var model
    @Environment(VaultAccess.self) private var access

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Approvals")
                .toolbar { AccountToolbarButton() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading:
            SneakerLoaderView(size: 96)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .modifier(KeepFresh(model: model))
        case let .failed(message):
            ContentUnavailableView {
                Label("Couldn't load approvals", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            }
            .modifier(KeepFresh(model: model))
        case .loaded:
            list.modifier(KeepFresh(model: model))
        }
    }

    private var list: some View {
        List {
            if let message = model.message {
                Section { Text(message).foregroundStyle(.red).accessibilityIdentifier("approvalsMessage") }
            }
            if model.awaitingCount == 0 {
                ContentUnavailableView(
                    "Nothing waiting",
                    systemImage: "checkmark.shield",
                    description: Text("Requests and reveals that need your decision show up here.")
                )
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("approvalsEmpty")
            }
            if !model.board.awaiting.isEmpty {
                Section("Requests") {
                    ForEach(model.board.awaiting) { row in
                        RequestCard(row: row) { decideButtons(row) }
                    }
                }
            }
            if !model.usesToDecide.isEmpty {
                Section("Reveals") {
                    ForEach(model.usesToDecide) { use in
                        UseCard(use: use) { useButtons(use) }
                    }
                }
            }
            let decided = model.board.history.filter { !$0.mine }
            if !decided.isEmpty {
                Section("Decided") {
                    ForEach(decided) { RequestCard(row: $0) }
                }
            }
        }
    }

    private func decideButtons(_ row: RequestRow) -> some View {
        HStack {
            Menu("Approve", systemImage: "checkmark.circle") {
                ForEach(GrantHours.choices, id: \.self) { hours in
                    Button("For \(hours) \(hours == 1 ? "hour" : "hours")") {
                        Task { await model.decide(row.id, approve: true, hours: hours, access) }
                    }
                    .accessibilityIdentifier("approve.\(row.id).\(hours)")
                }
            }
            .accessibilityIdentifier("approve.\(row.id)")
            Spacer()
            Button("Deny", systemImage: "xmark.circle", role: .destructive) {
                Task { await model.decide(row.id, approve: false, hours: GrantHours.standard, access) }
            }
            .accessibilityIdentifier("deny.\(row.id)")
        }
        .buttonStyle(.bordered)
        .disabled(model.isWorking)
    }

    private func useButtons(_ use: SecretUse) -> some View {
        HStack {
            Button("Approve", systemImage: "checkmark.circle") {
                Task { await model.decideUse(use, approve: true, access) }
            }
            .accessibilityIdentifier("approveUse.\(use.id)")
            Spacer()
            Button("Deny", systemImage: "xmark.circle", role: .destructive) {
                Task { await model.decideUse(use, approve: false, access) }
            }
            .accessibilityIdentifier("denyUse.\(use.id)")
        }
        .buttonStyle(.bordered)
        .disabled(model.isWorking)
    }
}
