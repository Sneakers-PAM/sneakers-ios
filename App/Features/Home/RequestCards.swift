// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

/// One request: what was asked for, by whom, why, how it stands, and its conversation. The same card serves both
/// screens; the Approvals screen adds the buttons to decide.
struct RequestCard<Actions: View>: View {
    let row: RequestRow
    @ViewBuilder let actions: () -> Actions

    @Environment(RequestsModel.self) private var model
    @Environment(VaultAccess.self) private var access
    @State private var showsConversation = false
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.title).font(.headline)
                Spacer()
                StatusPill(status: row.request.status)
            }
            Text(row.mine ? "You asked" : "From \(row.requestedBy)")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let reason = row.request.reason, !reason.isEmpty {
                Text(reason)
            }
            if let asked = row.request.requestedAt {
                Text(asked.formatted(.relative(presentation: .named)))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            actions()
            DisclosureGroup(
                "Conversation (\(row.request.comments.count))",
                isExpanded: $showsConversation
            ) {
                ForEach(row.request.comments) { comment in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(comment.authorName.isEmpty ? "Someone" : comment.authorName)
                            .font(.footnote.bold())
                        Text(comment.body)
                    }
                    .padding(.vertical, 2)
                }
                HStack {
                    TextField("Add a comment", text: $draft)
                        .accessibilityIdentifier("comment.\(row.id)")
                    Button("Send") {
                        let text = draft
                        draft = ""
                        Task { await model.comment(row.id, body: text, access) }
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .font(.subheadline)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("request.\(row.id)")
    }
}

extension RequestCard where Actions == EmptyView {
    init(row: RequestRow) {
        self.init(row: row) { EmptyView() }
    }
}

/// Pending, approved or denied, as a coloured word.
struct StatusPill: View {
    let status: ApprovalStatus

    private var color: Color {
        switch status {
        case .pending: .orange
        case .approved: .green
        case .denied: .red
        }
    }

    var body: some View {
        Text(status.label)
            .font(.caption.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
    }
}

/// A reveal someone asked for, with when it runs out.
struct UseCard<Actions: View>: View {
    let use: SecretUse
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Reveal of \(use.secretName)").font(.headline)
            Text("\(use.fieldKey), asked by \(use.requestedBy) through \(use.requester)")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if !use.purpose.isEmpty {
                Text(use.purpose)
            }
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let left = LeaseCountdown.remaining(until: use.expiresAt, now: context.date)
                Text("Expires in \(LeaseCountdown.text(remaining: left))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            actions()
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("use.\(use.id)")
    }
}
