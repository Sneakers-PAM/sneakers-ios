// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

/// Edits a secret's name and fields. Saving sends only what changed.
struct EditSecretView: View {
    @Bindable var model: EditSecretModel
    let onSaved: () -> Void

    @Environment(VaultAccess.self) private var access
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Name", text: $model.name)
                        .accessibilityIdentifier("edit.name")
                }
                Section("Fields") {
                    ForEach(model.editableFields, id: \.key) { field in
                        FieldEditor(
                            definition: field,
                            text: Binding(get: { model.value(for: field.key) }, set: { model.set($0, for: field.key) }),
                            error: model.error(for: field.key)
                        )
                    }
                }
                if let message = model.message {
                    Section {
                        Text(message)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("editMessage")
                    }
                }
            }
            .navigationTitle("Edit secret")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("editCancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(!model.canSave)
                        .accessibilityIdentifier("editSave")
                }
            }
        }
        .interactiveDismissDisabled(model.change != nil)
    }

    private func save() async {
        await model.save(access)
        if model.didSave {
            onSaved()
            dismiss()
        }
    }
}
