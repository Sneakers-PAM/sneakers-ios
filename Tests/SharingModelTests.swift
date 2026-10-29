// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Sneakers_PAM
import Testing

@MainActor
struct SharingModelTests {
    private let vault = FakeVaultService()

    private func makeAccess() -> VaultAccess {
        VaultAccess(service: vault, context: { .fixture }, onSessionEnded: {})
    }

    private var ruleset: Ruleset {
        let rule = AccessRule(
            id: "r1", subjectKind: "user", subjectName: "u9", subjectId: nil,
            grants: [RuleGrant(action: .reveal, value: .allow)]
        )
        return Ruleset(rules: [rule], inherited: [], owners: ["u1"], labels: ["u9": "Dave"])
    }

    @Test func startsLoading() {
        #expect(SharingModel(target: .secret(id: "s1"), canEdit: true).phase == .loading)
    }

    @Test func loadingShowsTheRulesAndNamesForPeople() async throws {
        vault.rulesetResult = .success(ruleset)
        let model = SharingModel(target: .secret(id: "s1"), canEdit: true)

        await model.load(makeAccess())

        #expect(model.phase == .loaded)
        #expect(model.draft?.rules.map(\.id) == ["r1"])
        #expect(try model.name(for: #require(model.draft?.rules[0])) == "Dave")
    }

    @Test func rulesThatCannotLoadSaySoAndCanBeRetried() async {
        vault.rulesetResult = .failure(.noAccess)
        let model = SharingModel(target: .folder(id: "f1"), canEdit: true)

        await model.load(makeAccess())

        #expect(model.phase == .failed(VaultError.noAccess.message))
    }

    @Test func nothingIsChangedUntilACellIsTapped() async {
        vault.rulesetResult = .success(ruleset)
        let model = SharingModel(target: .secret(id: "s1"), canEdit: true)
        await model.load(makeAccess())
        #expect(!model.canSave)

        model.cycle(rule: 0, .manage)

        #expect(model.canSave)
    }

    @Test func someoneWhoCannotEditCannotChangeOrSave() async {
        vault.rulesetResult = .success(ruleset)
        let model = SharingModel(target: .secret(id: "s1"), canEdit: false)
        await model.load(makeAccess())

        model.cycle(rule: 0, .manage)
        await model.save(makeAccess())

        #expect(!model.canSave)
        #expect(vault.savedSecretRules.isEmpty)
    }

    @Test func savingASecretsRulesSendsTheDraft() async {
        vault.rulesetResult = .success(ruleset)
        let model = SharingModel(target: .secret(id: "s1"), canEdit: true)
        await model.load(makeAccess())
        model.cycle(rule: 0, .manage)

        await model.save(makeAccess())

        #expect(vault.savedSecretRules.first?.secretID == "s1")
        #expect(vault.savedSecretRules.first?.rules.first?.value(for: .manage) == .allow)
        #expect(model.didSave)
    }

    @Test func savingAFoldersRulesKeepsItsOwners() async {
        vault.rulesetResult = .success(ruleset)
        let model = SharingModel(target: .folder(id: "f1"), canEdit: true)
        await model.load(makeAccess())
        model.remove(at: 0)

        await model.save(makeAccess())

        #expect(vault.savedFolderRules.first?.folderID == "f1")
        #expect(vault.savedFolderRules.first?.update.owners == ["u1"])
        #expect(vault.savedFolderRules.first?.update.rules.isEmpty == true)
    }

    @Test func aRefusedSaveSaysWhyAndKeepsTheDraft() async {
        vault.rulesetResult = .success(ruleset)
        vault.saveRulesResult = .failure(.noAccess)
        let model = SharingModel(target: .secret(id: "s1"), canEdit: true)
        await model.load(makeAccess())
        model.cycle(rule: 0, .manage)

        await model.save(makeAccess())

        #expect(!model.didSave)
        #expect(model.message == VaultError.noAccess.message)
        #expect(model.canSave)
    }

    @Test func searchingFindsPeopleAndAddingOneAddsAnEmptyRule() async throws {
        vault.rulesetResult = .success(ruleset)
        vault.peopleResult = .success([Person(id: "u2", name: "Eve", username: "eve")])
        let model = SharingModel(target: .secret(id: "s1"), canEdit: true)
        await model.load(makeAccess())

        model.searchQuery = "ev"
        await model.search(makeAccess())
        #expect(model.people.map(\.name) == ["Eve"])

        model.add(model.people[0])
        #expect(model.draft?.rules.map(\.subjectName) == ["u9", "u2"])
        #expect(try model.name(for: #require(model.draft?.rules[1])) == "Eve")
        #expect(model.people.isEmpty)
    }

    @Test func aShortSearchAsksNobody() async {
        let model = SharingModel(target: .secret(id: "s1"), canEdit: true)
        model.searchQuery = "e"

        await model.search(makeAccess())

        #expect(model.people.isEmpty)
    }
}
