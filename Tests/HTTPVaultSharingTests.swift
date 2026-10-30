// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Sneakers_PAM
import Testing

struct HTTPVaultSharingTests {
    private let transport = FakeGraphQLTransport()
    private var service: HTTPVaultService {
        HTTPVaultService(transport: transport)
    }

    private let rulesJSON = """
    [{"id":"r1","order":1,"subjectKind":"user","subjectName":"u9","subjectId":null,
      "grants":[{"action":"C","value":"allow"},{"action":"R","value":"deny"}]},
     {"id":"r2","order":2,"subjectKind":"everyone","subjectName":"","subjectId":null,"grants":[]}]
    """

    @Test func aSecretsRulesComeWithTheInheritedOnesAndNamesForPeople() async throws {
        transport.answer("SharingSecretRuleset", """
        {"secretRuleset":{"secretId":"s1","rules":\(rulesJSON),
          "inherited":[{"fromFolderId":"f1","fromFolderName":"Platform","rule":{"id":"r9","order":1,
            "subjectKind":"group","subjectName":"DB team","subjectId":"g1",
            "grants":[{"action":"I","value":"allow"}]}}]}}
        """)
        transport.answer("SharingUserLabels", #"{"resolveUserLabels":[{"id":"u9","name":"Dave"}]}"#)

        let ruleset = try await service.ruleset(forSecret: "s1", .fixture)

        #expect(ruleset.rules.map(\.id) == ["r1", "r2"])
        #expect(ruleset.rules.first?.value(for: .reveal) == .allow)
        #expect(ruleset.rules.first?.value(for: .manage) == .deny)
        #expect(ruleset.inherited.first?.fromFolderName == "Platform")
        #expect(ruleset.inherited.first?.rule.subjectName == "DB team")
        #expect(ruleset.labels["u9"] == "Dave")
        #expect(transport.operation(named: "SharingSecretRuleset")?.variables["secretId"] == .string("s1"))
    }

    @Test func aFoldersRulesComeWithItsOwners() async throws {
        transport.answer("SharingFolderRuleset", """
        {"folderRuleset":{"folderId":"f1","owners":["u1"],"rules":\(rulesJSON),"inherited":[]}}
        """)
        transport.answer("SharingUserLabels", #"{"resolveUserLabels":[{"id":"u1","name":"Alice"}]}"#)

        let ruleset = try await service.ruleset(forFolder: "f1", .fixture)

        #expect(ruleset.owners == ["u1"])
        #expect(ruleset.labels["u1"] == "Alice")
    }

    @Test func noPeopleMeansNoLabelLookup() async throws {
        transport.answer("SharingSecretRuleset", """
        {"secretRuleset":{"secretId":"s1","rules":[{"id":"r2","order":1,"subjectKind":"everyone","subjectName":"",
          "subjectId":null,"grants":[]}],"inherited":[]}}
        """)

        _ = try await service.ruleset(forSecret: "s1", .fixture)

        #expect(transport.operation(named: "SharingUserLabels") == nil)
    }

    @Test func savingASecretsRulesSendsEachRuleWithItsGrants() async throws {
        transport.answer("SharingSetSecretRuleset", #"{"setSecretRuleset":{"secretId":"s1"}}"#)
        var rule = AccessRule(id: "r1", subjectKind: "user", subjectName: "u9", subjectId: nil, grants: [])
        rule.cycle(.reveal)

        try await service.saveRules(forSecret: "s1", [rule], .fixture)

        let variables = transport.operation(named: "SharingSetSecretRuleset")?.variables
        #expect(variables?["secretId"] == .string("s1"))
        guard case let .list(rules)? = variables?["rules"], case let .object(sent)? = rules.first else {
            Issue.record("the rules are missing")
            return
        }
        #expect(sent["subjectKind"] == .string("user"))
        #expect(sent["subjectName"] == .string("u9"))
        guard case let .list(grants)? = sent["grants"], case let .object(grant)? = grants.first else {
            Issue.record("the grants are missing")
            return
        }
        #expect(grant["action"] == .string("C"))
        #expect(grant["value"] == .string("allow"))
    }

    @Test func savingAFoldersRulesKeepsItsOwners() async throws {
        transport.answer("SharingSetFolderRuleset", #"{"setFolderRuleset":{"folderId":"f1"}}"#)

        try await service.saveRules(forFolder: "f1", RulesUpdate(rules: [], owners: ["u1", "u2"]), .fixture)

        let variables = transport.operation(named: "SharingSetFolderRuleset")?.variables
        #expect(variables?["folderId"] == .string("f1"))
        #expect(variables?["owners"] == .list([.string("u1"), .string("u2")]))
    }

    @Test func peopleCanBeSearchedByName() async throws {
        transport.answer("SharingSearchUsers", """
        {"searchUsers":[{"id":"u2","name":"Eve","username":"eve"},{"id":"u3","name":"Evan","username":"evan"}]}
        """)

        let people = try await service.searchPeople("ev", .fixture)

        #expect(people.map(\.name) == ["Eve", "Evan"])
        #expect(transport.operation(named: "SharingSearchUsers")?.variables["query"] == .string("ev"))
    }

    @Test func aRefusedSaveSaysWhy() async {
        transport.fail("SharingSetSecretRuleset", .noAccess)

        await #expect(throws: VaultError.noAccess) {
            try await service.saveRules(forSecret: "s1", [], .fixture)
        }
    }

    @Test func theGroupsRulesCanBeAboutAreListed() async throws {
        transport.answer("SharingGroups", #"{"groups":[{"id":"g1","name":"DB team"},{"id":"g2","name":"Platform"}]}"#)

        let groups = try await service.groups(.fixture)

        #expect(groups.map(\.name) == ["DB team", "Platform"])
        #expect(groups.first?.id == "g1")
    }

    private let decisionJSON = """
    {"read":true,"readReason":"Allowed by DB team","reveal":false,"revealReason":"Denied by Everyone",
     "manage":false,"manageReason":"No rule","approve":false,"approveReason":"No rule",
     "informed":true,"informedReason":"Inherited"}
    """

    @Test func aSecretPreviewSendsTheDraftRulesForThatPerson() async throws {
        transport.answer("SharingSimulateSecret", #"{"simulateSecret":\#(decisionJSON)}"#)
        var rule = AccessRule(id: "n", subjectKind: "user", subjectName: "u9", subjectId: nil, grants: [])
        rule.cycle(.reveal)

        let preview = try await service.preview(
            PreviewRequest(target: .secret(id: "s1"), userID: "u9", rules: [rule]),
            .fixture
        )

        #expect(preview.read.allowed)
        #expect(preview.reveal.reason == "Denied by Everyone")
        let variables = transport.operation(named: "SharingSimulateSecret")?.variables
        #expect(variables?["secretId"] == .string("s1"))
        #expect(variables?["userId"] == .string("u9"))
        guard case let .list(rules)? = variables?["draftRules"] else {
            Issue.record("the draft rules are missing")
            return
        }
        #expect(rules.count == 1)
    }

    @Test func aFolderPreviewUsesTheFolderOperation() async throws {
        transport.answer("SharingSimulateFolder", #"{"simulateFolder":\#(decisionJSON)}"#)

        _ = try await service.preview(PreviewRequest(target: .folder(id: "f1"), userID: "u9", rules: []), .fixture)

        #expect(transport.operation(named: "SharingSimulateFolder")?.variables["folderId"] == .string("f1"))
    }
}
