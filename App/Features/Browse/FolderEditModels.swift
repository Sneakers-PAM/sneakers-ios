// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Observation
import os

private let editLogger = Logger(subsystem: "com.therabbithole.app.apple.sneakers-pam", category: "edit")

/// The name of a new folder, or a new name for an existing one.
@MainActor
@Observable
final class FolderNameModel {
    enum Mode: Equatable {
        case create(parentID: String?)
        case rename(id: String, currentName: String)
    }

    let mode: Mode
    var name: String
    private(set) var isSaving = false
    private(set) var didSave = false
    private(set) var message: String?

    init(mode: Mode) {
        self.mode = mode
        if case let .rename(_, currentName) = mode {
            name = currentName
        } else {
            name = ""
        }
    }

    private var trimmed: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSave: Bool {
        guard !trimmed.isEmpty, !isSaving else { return false }
        if case let .rename(_, currentName) = mode {
            return trimmed != currentName
        }
        return true
    }

    func save(_ access: VaultAccess) async {
        guard canSave else { return }
        isSaving = true
        message = nil
        defer { isSaving = false }
        let newName = trimmed
        do {
            switch mode {
            case let .create(parentID):
                _ = try await access.perform { try await access.service.createFolder(
                    parentID: parentID,
                    name: newName,
                    $0
                ) }
            case let .rename(id, _):
                try await access.perform { try await access.service.renameFolder(id: id, name: newName, $0) }
            }
            didSave = true
            editLogger.info("folder saved")
        } catch {
            message = (error as? VaultError ?? .unexpected).message
            editLogger.info("folder save failed")
        }
    }
}

/// A new secret: its type, its name and the values of its fields. Everything typed is forgotten once it is created.
@MainActor
@Observable
final class CreateSecretModel {
    let folderID: String
    let types: [SecretType]
    var name = ""
    private(set) var typeID: String?
    private(set) var isSaving = false
    private(set) var createdID: String?
    private(set) var message: String?
    private var drafts: [String: String] = [:]

    init(folderID: String, types: [SecretType]) {
        self.folderID = folderID
        self.types = types
        typeID = types.first?.id
    }

    static func loadTypes(_ access: VaultAccess) async -> [SecretType]? {
        try? await access.perform { try await access.service.secretTypes($0) }
    }

    var type: SecretType? {
        types.first { $0.id == typeID }
    }

    var editableFields: [FieldDefinition] {
        (type?.fields ?? []).filter { $0.fieldKind != .file }
    }

    func selectType(_ id: String) {
        guard id != typeID else { return }
        typeID = id
        drafts = [:]
    }

    func value(for key: String) -> String {
        drafts[key] ?? ""
    }

    func set(_ value: String, for key: String) {
        drafts[key] = value
        message = nil
    }

    func error(for key: String) -> String? {
        guard let field = editableFields.first(where: { $0.key == key }) else { return nil }
        let draft = value(for: key)
        if field.isRequired, draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return nil
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
        guard type != nil, !isSaving,
              !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return editableFields.allSatisfy { field in
            let draft = value(for: field.key).trimmingCharacters(in: .whitespacesAndNewlines)
            return (!field.isRequired || !draft.isEmpty) && error(for: field.key) == nil
        }
    }

    func save(_ access: VaultAccess) async {
        guard canSave, let type else { return }
        isSaving = true
        message = nil
        defer { isSaving = false }
        let secret = NewSecret(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines), folderID: folderID, typeID: type.id,
            fields: drafts.filter { !$0.value.isEmpty }
        )
        do {
            createdID = try await access.perform { try await access.service.createSecret(secret, $0) }
            for field in editableFields where field.isSensitive {
                drafts[field.key] = ""
            }
            editLogger.info("secret created")
        } catch {
            message = (error as? VaultError ?? .unexpected).message
            editLogger.info("secret create failed")
        }
    }
}

/// Moving a secret or a folder. The vault gates some moves, so the kind of move says what to ask first.
@MainActor
@Observable
final class MoveModel {
    enum Subject: Equatable {
        case secret(id: String, name: String, folderID: String)
        case folder(id: String, name: String, parentID: String?)
    }

    enum Outcome: Equatable {
        case moved
        case requested
    }

    let subject: Subject
    let destinations: [MoveDestination]
    var destinationID: String?
    var reason = ""
    private(set) var isSaving = false
    private(set) var outcome: Outcome?
    private(set) var message: String?
    private let tree: FolderTree

    init(subject: Subject, tree: FolderTree) {
        self.subject = subject
        self.tree = tree
        switch subject {
        case let .secret(_, _, folderID): destinations = tree.destinations(forSecretIn: folderID)
        case let .folder(id, _, _): destinations = tree.destinations(forFolder: id)
        }
    }

    private var source: String {
        switch subject {
        case let .secret(_, _, folderID): folderID
        case let .folder(id, _, _): id
        }
    }

    var kind: MoveKind? {
        destinationID.map { tree.moveKind(from: source, to: $0) }
    }

    var canMove: Bool {
        guard destinationID != nil, !isSaving, let kind else { return false }
        if kind == .request {
            return !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    func perform(_ access: VaultAccess) async {
        guard canMove, let destinationID, let kind else { return }
        isSaving = true
        message = nil
        defer { isSaving = false }
        let destinationName = destinations.first { $0.id == destinationID }?.label ?? ""
        do {
            if kind == .request {
                try await access.perform { try await access.service.requestMove(
                    self.request(destinationID, destinationName),
                    $0
                ) }
                outcome = .requested
            } else {
                try await access.perform { try await self.move(to: destinationID, access.service, $0) }
                outcome = .moved
            }
        } catch {
            message = (error as? VaultError ?? .unexpected).message
            editLogger.info("move failed")
        }
    }

    private func request(_ destinationID: String, _ destinationName: String) -> MoveRequest {
        let reason = reason
        switch subject {
        case let .secret(id, name, _):
            return MoveRequest(
                subject: .secret(id: id, name: name), destinationID: destinationID, destinationName: destinationName,
                reason: reason
            )
        case let .folder(id, name, _):
            return MoveRequest(
                subject: .folder(id: id, name: name), destinationID: destinationID, destinationName: destinationName,
                reason: reason
            )
        }
    }

    private func move(to destinationID: String, _ service: VaultServicing, _ context: ServerContext) async throws {
        switch subject {
        case let .secret(id, _, _): try await service.moveSecret(id: id, to: destinationID, context)
        case let .folder(id, _, _): try await service.moveFolder(id: id, to: destinationID, context)
        }
    }
}
