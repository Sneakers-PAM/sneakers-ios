// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Observation
import os

/// The draft of an edit to one secret. Plain fields start with their value. Sensitive fields start empty and are sent
/// only when something is typed, so the app never holds the old value. Only what changed is sent.
@MainActor
@Observable
final class EditSecretModel {
    private static let logger = Logger(subsystem: "com.therabbithole.app.apple.sneakers-pam", category: "edit")

    let secretID: String
    let editableFields: [FieldDefinition]
    var name: String
    private(set) var isSaving = false
    private(set) var didSave = false
    private(set) var message: String?

    private let originalName: String
    private let originalValues: [String: String]
    private var drafts: [String: String] = [:]

    init(secretID: String, name: String, fields: [FieldDefinition], values: [String: String]) {
        self.secretID = secretID
        self.name = name
        originalName = name
        originalValues = values
        editableFields = fields.filter { $0.fieldKind != .file }
        for field in editableFields {
            drafts[field.key] = field.isSensitive ? "" : (values[field.key] ?? "")
        }
    }

    func value(for key: String) -> String {
        drafts[key] ?? ""
    }

    func set(_ value: String, for key: String) {
        drafts[key] = value
        message = nil
    }

    /// What would be sent, or nil when nothing changed.
    var change: SecretChange? {
        var fields: [String: String] = [:]
        for field in editableFields {
            let draft = value(for: field.key)
            if field.isSensitive {
                if !draft.isEmpty {
                    fields[field.key] = draft
                }
            } else if draft != (originalValues[field.key] ?? "") {
                fields[field.key] = draft
            }
        }
        let renamed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let newName = renamed != originalName ? renamed : nil
        guard newName != nil || !fields.isEmpty else { return nil }
        return SecretChange(name: newName, fields: fields)
    }

    func error(for key: String) -> String? {
        guard let field = editableFields.first(where: { $0.key == key }) else { return nil }
        let draft = value(for: key)
        if field.isRequired, !field.isSensitive, draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "\(field.label) is required."
        }
        if let limit = field.maxLength, limit > 0, draft.count > limit {
            return "\(field.label) can be at most \(limit) characters."
        }
        if field.fieldKind == .select, !draft.isEmpty, let options = field.options, !options.contains(draft) {
            return "Pick one of the choices."
        }
        return nil
    }

    var canSave: Bool {
        guard change != nil, !isSaving,
              !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return editableFields.allSatisfy { error(for: $0.key) == nil }
    }

    func save(_ access: VaultAccess) async {
        guard canSave, let change else { return }
        isSaving = true
        message = nil
        defer { isSaving = false }
        do {
            try await access.perform { try await access.service.update(secretID: self.secretID, change, $0) }
            for field in editableFields where field.isSensitive {
                drafts[field.key] = ""
            }
            didSave = true
            Self.logger.info("secret saved")
        } catch {
            let failure = error as? VaultError ?? .unexpected
            Self.logger.info("secret save failed: \(String(describing: failure), privacy: .public)")
            message = failure.message
        }
    }
}

extension EditSecretModel: Identifiable {
    nonisolated var id: String {
        secretID
    }
}
