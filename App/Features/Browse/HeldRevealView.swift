// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

/// Shown in place of a value while the vault holds its reveal for approval. The value is read on its own once someone
/// approves, so nothing here asks for it.
struct HeldRevealView: View {
    let use: HeldReveal
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
            VStack(alignment: .leading, spacing: 2) {
                Text("Waiting for approval")
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let left = LeaseCountdown.remaining(until: use.expiresAt, now: context.date)
                    Text("Asked for. Expires in \(LeaseCountdown.text(remaining: left))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            Spacer()
            Button("Cancel", action: onCancel)
                .buttonStyle(.borderless)
                .accessibilityIdentifier("cancelHeld")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("heldReveal")
    }
}
