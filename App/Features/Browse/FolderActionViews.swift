// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

/// Names a new folder, or renames one.
struct FolderNameView: View {
    @Bindable var model: FolderNameModel
    let onSaved: () -> Void

    @Environment(VaultAccess.self) private var access
    @Environment(\.dismiss) private var dismiss

    private var title: String {
        if case .create = model.mode {
            "New folder"
        } else {
            "Rename folder"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $model.name)
                        .accessibilityIdentifier("folderName")
                }
                if let message = model.message {
                    Section { Text(message).foregroundStyle(.red) }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(!model.canSave)
                        .accessibilityIdentifier("folderNameSave")
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() async {
        await model.save(access)
        if model.didSave {
            onSaved()
            dismiss()
        }
    }
}

/// Makes a new secret in a folder: a type, a name and its fields.
struct CreateSecretView: View {
    @Bindable var model: CreateSecretModel
    let onCreated: (String) -> Void

    @Environment(VaultAccess.self) private var access
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: Binding(get: { model.typeID ?? "" }, set: { model.selectType($0) })) {
                        ForEach(model.types) { type in
                            Text(type.name).tag(type.id)
                        }
                    }
                    .accessibilityIdentifier("newSecretType")
                    TextField("Name", text: $model.name)
                        .accessibilityIdentifier("newSecretName")
                }
                Section("Fields") {
                    ForEach(model.editableFields, id: \.key) { field in
                        FieldEditor(
                            definition: field,
                            text: Binding(get: { model.value(for: field.key) }, set: { model.set($0, for: field.key) }),
                            error: model.error(for: field.key),
                            isNew: true
                        )
                    }
                }
                if let message = model.message {
                    Section { Text(message).foregroundStyle(.red) }
                }
            }
            .navigationTitle("New secret")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { Task { await create() } }
                        .disabled(!model.canSave)
                        .accessibilityIdentifier("newSecretCreate")
                }
            }
        }
    }

    private func create() async {
        await model.save(access)
        if let id = model.createdID {
            onCreated(id)
            dismiss()
        }
    }
}

/// Picks where a secret or folder goes. A move into a personal folder is a request, so it asks why.
struct MoveView: View {
    @Bindable var model: MoveModel
    let onDone: () -> Void

    @Environment(VaultAccess.self) private var access
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Move to") {
                    Picker("Folder", selection: $model.destinationID) {
                        Text("Choose").tag(String?.none)
                        ForEach(model.destinations) { destination in
                            Text(destination.label).tag(Optional(destination.id))
                        }
                    }
                    .accessibilityIdentifier("moveDestination")
                }
                if let note {
                    Section {
                        Text(note).font(.footnote).foregroundStyle(.secondary)
                        if model.kind == .request {
                            TextField("Why", text: $model.reason, axis: .vertical)
                                .accessibilityIdentifier("moveReason")
                        }
                    }
                }
                if let message = model.message {
                    Section { Text(message).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Move")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(model.kind == .request ? "Ask" : "Move") { Task { await perform() } }
                        .disabled(!model.canMove)
                        .accessibilityIdentifier("moveConfirm")
                }
            }
        }
    }

    private var note: String? {
        switch model.kind {
        case .request: "A shared item going into a personal folder needs a site admin's approval. This sends a request."
        case .share: "Moving out of a personal folder shares it with the people who can see the destination."
        case .direct, nil: nil
        }
    }

    private func perform() async {
        await model.perform(access)
        if model.outcome != nil {
            onDone()
            dismiss()
        }
    }
}
