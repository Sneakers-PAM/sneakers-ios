// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// The four cells of an access rule, in the order the web shows them. The gateway names them C, I, A and R.
nonisolated enum RuleAction: CaseIterable, Sendable {
    case reveal, informed, approve, manage

    var gatewayKey: String {
        switch self {
        case .reveal: "C"
        case .informed: "I"
        case .approve: "A"
        case .manage: "R"
        }
    }

    init?(gatewayKey: String) {
        guard let match = Self.allCases.first(where: { $0.gatewayKey == gatewayKey }) else { return nil }
        self = match
    }

    var label: String {
        switch self {
        case .reveal: "Reveal"
        case .informed: "Informed"
        case .approve: "Approve"
        case .manage: "Manage"
        }
    }
}

/// What one cell says. A blank cell falls through to the next rule.
nonisolated enum GrantValue: String, Sendable {
    case allow, deny, own

    /// Tapping a cell goes from blank to allow to deny and back to blank.
    static func next(after value: GrantValue?) -> GrantValue? {
        switch value {
        case nil: .allow
        case .allow: .deny
        case .deny, .own: nil
        }
    }
}

nonisolated struct RuleGrant: Equatable, Sendable {
    let action: RuleAction
    let value: GrantValue
}

/// One row of a ruleset: who it is about and what it allows or denies them.
nonisolated struct AccessRule: Equatable, Identifiable, Sendable {
    let id: String
    let subjectKind: String
    let subjectName: String
    let subjectId: String?
    var grants: [RuleGrant]

    var displayName: String {
        displayName(labels: [:])
    }

    func displayName(labels: [String: String]) -> String {
        switch subjectKind {
        case "everyone": "Everyone"
        case "user": labels[subjectName] ?? subjectName
        default: subjectName
        }
    }

    func value(for action: RuleAction) -> GrantValue? {
        grants.first { $0.action == action }?.value
    }

    mutating func cycle(_ action: RuleAction) {
        let next = GrantValue.next(after: value(for: action))
        grants.removeAll { $0.action == action }
        if let next {
            grants.append(RuleGrant(action: action, value: next))
        }
    }

    var summary: String {
        func names(_ wanted: [GrantValue]) -> [String] {
            RuleAction.allCases.compactMap { action in
                guard let value = value(for: action), wanted.contains(value) else { return nil }
                return value == .own ? "\(action.label) (own)" : action.label
            }
        }
        let allowed = names([.allow, .own])
        let denied = names([.deny])
        var parts: [String] = []
        if !allowed.isEmpty {
            parts.append("Allows " + allowed.joined(separator: ", ") + ".")
        }
        if !denied.isEmpty {
            parts.append("Denies " + denied.joined(separator: ", ") + ".")
        }
        return parts.isEmpty ? "No grants" : parts.joined(separator: " ")
    }
}

/// Something rules are about: a secret or a folder.
nonisolated enum SharingTarget: Equatable, Sendable {
    case secret(id: String)
    case folder(id: String)
}

/// A question for the preview: what could this person do on this target if these rules were in effect.
nonisolated struct PreviewRequest: Equatable, Sendable {
    let target: SharingTarget
    let userID: String
    let rules: [AccessRule]
}

/// A group a rule can be about.
nonisolated struct RuleGroup: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String
}

/// One answer in a preview: allowed or not, and the rule or inheritance that decided it.
nonisolated struct Decision: Equatable, Sendable {
    let allowed: Bool
    let reason: String
}

/// What a person could do if the rules being edited were saved, with the reason for each answer. Nothing is saved to
/// get it.
nonisolated struct AccessPreview: Equatable, Sendable {
    struct Line: Equatable {
        let label: String
        let decision: Decision
    }

    let read: Decision
    let reveal: Decision
    let manage: Decision
    let approve: Decision
    let informed: Decision

    var lines: [Line] {
        var all = [Line(label: "Read", decision: read)]
        all.append(Line(label: "Reveal", decision: reveal))
        all.append(Line(label: "Manage", decision: manage))
        all.append(Line(label: "Approve", decision: approve))
        all.append(Line(label: "Informed", decision: informed))
        return all
    }
}

/// What a folder's rules save as: the rules, and the owners kept alongside them.
nonisolated struct RulesUpdate: Equatable, Sendable {
    var rules: [AccessRule]
    var owners: [String]
}

/// A rule from a folder above, shown but not editable here.
nonisolated struct InheritedRule: Equatable, Identifiable, Sendable {
    let rule: AccessRule
    let fromFolderName: String

    var id: String {
        rule.id
    }
}

nonisolated struct Ruleset: Equatable, Sendable {
    var rules: [AccessRule]
    var inherited: [InheritedRule]
    var owners: [String]
    /// Names for the people the rules mention, by id.
    var labels: [String: String] = [:]
}

/// The rules as they are being edited, kept next to how they started so it is clear whether anything changed.
nonisolated struct RulesetDraft: Equatable, Sendable {
    private(set) var rules: [AccessRule]
    private(set) var labels: [String: String]
    private let original: [AccessRule]

    init(rules: [AccessRule], labels: [String: String] = [:]) {
        self.rules = rules
        self.labels = labels
        original = rules
    }

    var isChanged: Bool {
        Self.normalised(rules) != Self.normalised(original)
    }

    mutating func cycle(rule index: Int, _ action: RuleAction) {
        guard rules.indices.contains(index) else { return }
        rules[index].cycle(action)
    }

    mutating func remove(at index: Int) {
        guard rules.indices.contains(index) else { return }
        rules.remove(at: index)
    }

    mutating func addUser(id: String, label: String) {
        guard !rules.contains(where: { $0.subjectKind == "user" && $0.subjectName == id }) else { return }
        labels[id] = label
        rules.append(AccessRule(id: "new-\(id)", subjectKind: "user", subjectName: id, subjectId: nil, grants: []))
    }

    mutating func addGroup(id: String, name: String) {
        guard !rules.contains(where: { $0.subjectKind == "group" && $0.subjectId == id }) else { return }
        rules.append(AccessRule(
            id: "new-group-\(id)",
            subjectKind: "group",
            subjectName: name,
            subjectId: id,
            grants: []
        ))
    }

    mutating func addEveryone() {
        guard !rules.contains(where: { $0.subjectKind == "everyone" }) else { return }
        rules.append(AccessRule(
            id: "new-everyone",
            subjectKind: "everyone",
            subjectName: "",
            subjectId: nil,
            grants: []
        ))
    }

    private static func normalised(_ rules: [AccessRule]) -> [String] {
        rules.map { rule in
            let cells = RuleAction.allCases.map { rule.value(for: $0)?.rawValue ?? "-" }.joined()
            return "\(rule.subjectKind)|\(rule.subjectName)|\(cells)"
        }
    }
}
