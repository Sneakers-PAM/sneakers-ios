// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

#if DEBUG
    import Foundation
    import os

    /// Who can access a secret or folder in the made-up vault.
    extension DemoVaultService {
        func ruleset(forSecret _: String, _: ServerContext) async throws -> Ruleset {
            demoRuleset()
        }

        func ruleset(forFolder _: String, _: ServerContext) async throws -> Ruleset {
            demoRuleset()
        }

        func saveRules(forSecret _: String, _ rules: [AccessRule], _: ServerContext) async throws {
            state.withLock { $0.savedRules = rules }
        }

        func saveRules(forFolder _: String, _ update: RulesUpdate, _: ServerContext) async throws {
            state.withLock { $0.savedRules = update.rules }
        }

        func searchPeople(_ query: String, _: ServerContext) async throws -> [Person] {
            [Person(id: "u-eve", name: "Eve", username: "eve")].filter {
                $0.name.localizedCaseInsensitiveContains(query)
            }
        }

        func demoRuleset() -> Ruleset {
            let saved = state.withLock { $0.savedRules }
            let reveal = RuleGrant(action: .reveal, value: .allow)
            let team = AccessRule(
                id: "r1",
                subjectKind: "group",
                subjectName: "DB team",
                subjectId: "g1",
                grants: [reveal]
            )
            let above = InheritedRule(
                rule: AccessRule(
                    id: "r9", subjectKind: "everyone", subjectName: "", subjectId: nil,
                    grants: [RuleGrant(action: .informed, value: .allow)]
                ),
                fromFolderName: "Platform"
            )
            return Ruleset(
                rules: saved ?? [team],
                inherited: [above],
                owners: ["u1"],
                labels: ["u-eve": "Eve", "u1": "Alice"]
            )
        }
    }
#endif
