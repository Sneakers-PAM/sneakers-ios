// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Sneakers_PAM
import Testing

struct SharingModelsTests {
    private func rule(
        _ id: String, kind: String = "user", name: String = "u1", grants: [RuleGrant] = []
    ) -> AccessRule {
        AccessRule(id: id, subjectKind: kind, subjectName: name, subjectId: nil, grants: grants)
    }

    @Test func eachActionHasItsWordFromTheWeb() {
        #expect(RuleAction.reveal.label == "Reveal")
        #expect(RuleAction.informed.label == "Informed")
        #expect(RuleAction.approve.label == "Approve")
        #expect(RuleAction.manage.label == "Manage")
        #expect(RuleAction.allCases.map(\.gatewayKey) == ["C", "I", "A", "R"])
    }

    @Test func aRuleSummarisesWhatItAllowsAndDenies() {
        var item = rule("1")
        item.cycle(.reveal)
        item.cycle(.informed)
        item.cycle(.manage)
        item.cycle(.manage)

        #expect(item.summary == "Allows Reveal, Informed. Denies Manage.")
    }

    @Test func aRuleWithNoGrantsSaysItDoesNothing() {
        #expect(rule("1").summary == "No grants")
    }

    @Test func aRuleIsNamedByItsSubject() {
        #expect(rule("1", kind: "everyone", name: "").displayName == "Everyone")
        #expect(rule("1", kind: "group", name: "DB team").displayName == "DB team")
        #expect(AccessRule(id: "1", subjectKind: "user", subjectName: "u9", subjectId: nil, grants: [])
            .displayName(labels: ["u9": "Dave"]) == "Dave")
    }

    @Test func aGrantCyclesFromBlankToAllowToDenyAndBack() {
        #expect(GrantValue.next(after: nil) == .allow)
        #expect(GrantValue.next(after: .allow) == .deny)
        #expect(GrantValue.next(after: .deny) == nil)
    }

    @Test func cyclingACellChangesOnlyThatCell() {
        var item = rule("1", grants: [RuleGrant(action: .reveal, value: .allow)])

        item.cycle(.manage)
        item.cycle(.reveal)

        #expect(item.value(for: .manage) == .allow)
        #expect(item.value(for: .reveal) == .deny)
        #expect(item.value(for: .approve) == nil)
    }

    @Test func aDraftCanAddAPersonOnceAndRemoveARule() {
        var draft = RulesetDraft(rules: [rule("1", name: "u1")])

        draft.addUser(id: "u2", label: "Eve")
        draft.addUser(id: "u2", label: "Eve")
        #expect(draft.rules.map(\.subjectName) == ["u1", "u2"])
        #expect(draft.labels["u2"] == "Eve")

        draft.remove(at: 0)
        #expect(draft.rules.map(\.subjectName) == ["u2"])
    }

    @Test func aDraftKnowsWhenItChanged() {
        var draft = RulesetDraft(rules: [rule("1", grants: [RuleGrant(action: .reveal, value: .allow)])])
        #expect(!draft.isChanged)

        draft.cycle(rule: 0, .reveal)
        #expect(draft.isChanged)

        draft.cycle(rule: 0, .reveal)
        draft.cycle(rule: 0, .reveal)
        #expect(!draft.isChanged)
    }
}
