// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Observation
import os

/// Who can access one secret or folder: its rules and the ones inherited, and, for someone allowed to, changing them.
/// The server still decides who may save, and refuses anyone who may not.
@MainActor
@Observable
final class SharingModel {
    enum Target: Equatable {
        case secret(id: String)
        case folder(id: String)
    }

    enum Phase: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    private static let logger = Logger(subsystem: "com.therabbithole.app.apple.sneakers-pam", category: "sharing")
    private static let shortestSearch = 2

    let target: Target
    let canEdit: Bool
    var searchQuery = ""
    private(set) var phase = Phase.loading
    private(set) var ruleset: Ruleset?
    private(set) var draft: RulesetDraft?
    private(set) var people: [Person] = []
    private(set) var isSaving = false
    private(set) var didSave = false
    private(set) var message: String?

    init(target: Target, canEdit: Bool) {
        self.target = target
        self.canEdit = canEdit
    }

    var canSave: Bool {
        canEdit && !isSaving && draft?.isChanged == true
    }

    func name(for rule: AccessRule) -> String {
        rule.displayName(labels: draft?.labels ?? ruleset?.labels ?? [:])
    }

    func load(_ access: VaultAccess) async {
        do {
            let loaded: Ruleset = switch target {
            case let .secret(id): try await access.perform { try await access.service.ruleset(forSecret: id, $0) }
            case let .folder(id): try await access.perform { try await access.service.ruleset(forFolder: id, $0) }
            }
            ruleset = loaded
            draft = RulesetDraft(rules: loaded.rules, labels: loaded.labels)
            phase = .loaded
        } catch {
            let failure = error as? VaultError ?? .unexpected
            Self.logger.info("rules failed: \(String(describing: failure), privacy: .public)")
            phase = .failed(failure.message)
        }
    }

    func cycle(rule index: Int, _ action: RuleAction) {
        guard canEdit else { return }
        draft?.cycle(rule: index, action)
        didSave = false
    }

    func remove(at index: Int) {
        guard canEdit else { return }
        draft?.remove(at: index)
        didSave = false
    }

    func search(_ access: VaultAccess) async {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canEdit, query.count >= Self.shortestSearch else {
            people = []
            return
        }
        people = await (try? access.perform { try await access.service.searchPeople(query, $0) }) ?? []
    }

    func add(_ person: Person) {
        guard canEdit else { return }
        draft?.addUser(id: person.id, label: person.name)
        people = []
        searchQuery = ""
        didSave = false
    }

    func save(_ access: VaultAccess) async {
        guard canSave, let draft else { return }
        isSaving = true
        message = nil
        defer { isSaving = false }
        do {
            switch target {
            case let .secret(id):
                try await access.perform { try await access.service.saveRules(forSecret: id, draft.rules, $0) }
            case let .folder(id):
                let update = RulesUpdate(rules: draft.rules, owners: ruleset?.owners ?? [])
                try await access.perform { try await access.service.saveRules(forFolder: id, update, $0) }
            }
            didSave = true
            Self.logger.info("rules saved")
            await load(access)
        } catch {
            message = (error as? VaultError ?? .unexpected).message
            Self.logger.info("rules save failed")
        }
    }
}
