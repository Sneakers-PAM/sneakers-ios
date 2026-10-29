// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

/// The state of a secret's health check as a coloured dot and a word.
struct HealthPill: View {
    let status: HealthStatus

    private var color: Color {
        switch status {
        case .verified: .green
        case .drift, .unreachable: .red
        case .unknown: .orange
        case .none: .gray
        }
    }

    var body: some View {
        Label {
            Text(status.label)
        } icon: {
            Image(systemName: "circle.fill").foregroundStyle(color).imageScale(.small)
        }
        .accessibilityIdentifier("healthPill")
    }
}

/// The heartbeat of a secret: whether its target still accepts the stored value, when that was last checked, and
/// whether checking is switched on.
struct HeartbeatCard: View {
    let model: SecretDetailModel
    @Environment(VaultAccess.self) private var access

    var body: some View {
        if let detail = model.loadedDetail, checksHealth(detail) {
            Section("Heartbeat") {
                HStack {
                    HealthPill(status: detail.summary.health)
                    Spacer()
                    if let checked = detail.verifiedAt {
                        Text("Checked \(checked.formatted(.relative(presentation: .named)))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                if let note = note(detail) {
                    Text(note).font(.footnote).foregroundStyle(.secondary)
                }
                if model.canToggleHeartbeat {
                    Toggle(
                        "Check automatically",
                        isOn: Binding(
                            get: { !model.lifecycle.heartbeatOptOut },
                            set: { isOn in Task { await model.setHeartbeat(on: isOn, access) } }
                        )
                    )
                    .disabled(model.isWorking)
                    .accessibilityIdentifier("heartbeatToggle")
                }
            }
        }
    }

    private func checksHealth(_ detail: SecretDetail) -> Bool {
        detail.type?.supportsHeartbeat == true || detail.summary.targetId != nil
    }

    private func note(_ detail: SecretDetail) -> String? {
        if model.lifecycle.heartbeatOptOut {
            return "Checking is switched off for this secret."
        }
        if let hostKey = detail.summary.heartbeatNote {
            return hostKey
        }
        if let reason = model.lifecycle.heartbeatBlockedReason {
            return "Checking cannot run: \(reason)."
        }
        return nil
    }
}

/// The rotation of a secret: how the last one went, when the next is due, and the controls to rotate now or turn
/// automatic rotation off.
struct RotationCard: View {
    let model: SecretDetailModel
    @Environment(VaultAccess.self) private var access
    @State private var isConfirming = false

    var body: some View {
        if let detail = model.loadedDetail, detail.type?.supportsRotation == true {
            Section("Rotation") {
                LabeledContent("Last rotation", value: (model.lifecycle.rotation ?? .unknown).label)
                if let rotated = model.lifecycle.rotatedAt {
                    LabeledContent("Rotated", value: rotated.formatted(.relative(presentation: .named)))
                }
                if let next = detail.nextRotationAt, !model.lifecycle.rotationOptOut {
                    LabeledContent("Next rotation", value: next.formatted(date: .abbreviated, time: .shortened))
                }
                if model.canToggleRotation {
                    Toggle(
                        "Rotate automatically",
                        isOn: Binding(
                            get: { !model.lifecycle.rotationOptOut },
                            set: { isOn in Task { await model.setRotation(on: isOn, access) } }
                        )
                    )
                    .disabled(model.isWorking)
                    .accessibilityIdentifier("rotationToggle")
                }
                if model.canRotate {
                    rotateControls
                }
            }
        }
    }

    @ViewBuilder
    private var rotateControls: some View {
        if isConfirming {
            Text("The stored value changes now, on the target too.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack {
                Button("Rotate now", role: .destructive) {
                    isConfirming = false
                    Task { await model.rotateNow(access) }
                }
                .accessibilityIdentifier("rotateConfirm")
                Spacer()
                Button("Cancel") { isConfirming = false }
            }
            .buttonStyle(.bordered)
        } else {
            Button("Rotate now", systemImage: "arrow.triangle.2.circlepath") { isConfirming = true }
                .disabled(model.isWorking)
                .accessibilityIdentifier("rotateNow")
        }
    }
}

/// Retire a secret to hide it from the lists, or bring a retired one back.
struct LifecycleCard: View {
    let model: SecretDetailModel
    @Environment(VaultAccess.self) private var access
    @State private var isConfirming = false

    var body: some View {
        if model.canReinstate {
            Section {
                Label("This secret is retired.", systemImage: "archivebox")
                    .accessibilityIdentifier("retiredBanner")
                Button("Restore secret", systemImage: "arrow.uturn.backward") {
                    Task { await model.reinstate(access) }
                }
                .disabled(model.isWorking)
                .accessibilityIdentifier("reinstate")
            }
        } else if model.canRetire {
            Section {
                if isConfirming {
                    Text("It disappears from the lists. You can restore it later.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("Retire", role: .destructive) {
                            isConfirming = false
                            Task { await model.retire(access) }
                        }
                        .accessibilityIdentifier("retireConfirm")
                        Spacer()
                        Button("Cancel") { isConfirming = false }
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("Retire secret", systemImage: "archivebox", role: .destructive) { isConfirming = true }
                        .disabled(model.isWorking)
                        .accessibilityIdentifier("retire")
                }
            }
        }
    }
}
