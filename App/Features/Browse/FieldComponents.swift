// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

/// How a field's value is shown, by kind: a yes or no for a switch, a block for several lines, plain text otherwise.
struct FieldValueText: View {
    let kind: FieldKind
    let value: String

    var body: some View {
        switch kind {
        case .boolean:
            Text(value == "true" ? "Yes" : "No")
        case .multiline:
            Text(value)
                .font(.system(.footnote, design: .monospaced))
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                .textSelection(.enabled)
        default:
            Text(value)
        }
    }
}

/// The control that edits one field, chosen by the field's kind. A sensitive field is a hidden entry that starts
/// empty, because the app never holds the old value.
struct FieldEditor: View {
    let definition: FieldDefinition
    @Binding var text: String
    let error: String?
    /// Whether this is a new secret, where a sensitive field has no old value to keep.
    var isNew = false

    @State private var showsSecret = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            control
            if let error {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            } else if definition.isSensitive, !isNew {
                Text("Leave empty to keep the current value.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("edit.\(definition.key)")
    }

    @ViewBuilder
    private var control: some View {
        switch definition.fieldKind {
        case .boolean:
            Toggle(definition.label, isOn: Binding(get: { text == "true" }, set: { text = $0 ? "true" : "false" }))
        case .select:
            Picker(definition.label, selection: $text) {
                if !definition.isRequired {
                    Text("None").tag("")
                }
                ForEach(definition.options ?? [], id: \.self) { option in
                    Text(option).tag(option)
                }
            }
        case .multiline where !definition.isSensitive:
            VStack(alignment: .leading, spacing: 4) {
                Text(definition.label).font(.footnote).foregroundStyle(.secondary)
                TextEditor(text: $text)
                    .frame(minHeight: 120)
                    .font(.system(.body, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        default:
            if definition.isSensitive {
                secretEntry
            } else {
                TextField(definition.label, text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }
    }

    private var secretEntry: some View {
        HStack {
            Group {
                if showsSecret {
                    TextField(definition.label, text: $text)
                } else {
                    SecureField(definition.label, text: $text)
                }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            Button(showsSecret ? "Hide" : "Show", systemImage: showsSecret ? "eye.slash" : "eye") {
                showsSecret.toggle()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
        }
    }
}
