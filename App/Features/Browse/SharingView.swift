// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

/// Where the sharing screen is pushed to.
struct SharingRoute: Hashable {
    let secretID: String
}

/// Who can access a secret or folder. Each rule is a person or group with four cells: tapping one goes from blank to
/// allow to deny and back. Rules from folders above show too, and cannot be changed here.
struct SharingView: View {
    @State private var model: SharingModel
    @Environment(VaultAccess.self) private var access

    init(target: SharingModel.Target, canEdit: Bool) {
        _model = State(initialValue: SharingModel(target: target, canEdit: canEdit))
    }

    var body: some View {
        content
            .navigationTitle("Who has access")
            .navigationBarTitleDisplayMode(.inline)
            .task { await model.load(access) }
            .toolbar {
                if model.canEdit {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { Task { await model.save(access) } }
                            .disabled(!model.canSave)
                            .accessibilityIdentifier("sharingSave")
                    }
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading:
            SneakerLoaderView(size: 96).frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .failed(message):
            ContentUnavailableView {
                Label("Couldn't load who has access", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try again") { Task { await model.load(access) } }
            }
        case .loaded:
            list
        }
    }

    private var list: some View {
        List {
            if !model.canEdit {
                Section {
                    Label("You can see these rules but not change them.", systemImage: "eye")
                        .font(.footnote)
                }
            }
            rulesSection
            inheritedSection
            if model.canEdit {
                addSection
            }
            if let message = model.message {
                Section { Text(message).foregroundStyle(.red).accessibilityIdentifier("sharingMessage") }
            }
            if model.didSave {
                Section { Label("Saved.", systemImage: "checkmark.circle").accessibilityIdentifier("sharingSaved") }
            }
        }
    }

    private var rulesSection: some View {
        Section("Rules") {
            let rules = model.draft?.rules ?? []
            if rules.isEmpty {
                Text("No rules here.").foregroundStyle(.secondary)
            }
            ForEach(Array(rules.enumerated()), id: \.element.id) { index, rule in
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.name(for: rule)).font(.headline).accessibilityIdentifier("rule.\(index)")
                    HStack(spacing: 8) {
                        ForEach(RuleAction.allCases, id: \.self) { action in
                            CellButton(
                                action: action, value: rule.value(for: action), isEnabled: model.canEdit,
                                identifier: "cell.\(index).\(action.label.lowercased())"
                            ) {
                                model.cycle(rule: index, action)
                            }
                        }
                    }
                }
                .swipeActions(edge: .trailing) {
                    if model.canEdit {
                        Button("Remove", role: .destructive) { model.remove(at: index) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var inheritedSection: some View {
        let inherited = model.ruleset?.inherited ?? []
        if !inherited.isEmpty {
            Section("From folders above") {
                ForEach(inherited) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.rule.displayName(labels: model.ruleset?.labels ?? [:]))
                        Text(item.rule.summary).font(.footnote).foregroundStyle(.secondary)
                        Text("From \(item.fromFolderName)").font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var addSection: some View {
        Section("Add a person") {
            TextField("Search by name", text: $model.searchQuery)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onChange(of: model.searchQuery) { Task { await model.search(access) } }
                .accessibilityIdentifier("addPersonField")
            ForEach(model.people) { person in
                Button {
                    model.add(person)
                } label: {
                    VStack(alignment: .leading) {
                        Text(person.name)
                        Text(person.username).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("person.\(person.name)")
            }
        }
    }
}

/// One cell of a rule: its word, and whether it allows, denies or says nothing.
private struct CellButton: View {
    let action: RuleAction
    let value: GrantValue?
    let isEnabled: Bool
    let identifier: String
    let onTap: () -> Void

    private var symbol: String {
        switch value {
        case .allow, .own: "checkmark"
        case .deny: "xmark"
        case nil: "minus"
        }
    }

    private var color: Color {
        switch value {
        case .allow, .own: .green
        case .deny: .red
        case nil: .secondary
        }
    }

    private var spoken: String {
        switch value {
        case .allow: "allowed"
        case .own: "allowed for their own"
        case .deny: "denied"
        case nil: "not set"
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Image(systemName: symbol).foregroundStyle(color)
                Text(action.label).font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.borderless)
        .disabled(!isEnabled)
        .accessibilityLabel("\(action.label), \(spoken)")
        .accessibilityIdentifier(identifier)
    }
}
