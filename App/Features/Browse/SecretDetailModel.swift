// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Observation
import os

nonisolated struct FieldRow: Equatable, Identifiable, Sendable {
    let key: String
    let label: String
    let isSensitive: Bool
    /// The value, only for a field the server marks as safe to show. Sensitive values are never kept here.
    let plainValue: String?
    var kind = FieldKind.text

    var id: String {
        key
    }
}

nonisolated enum LeaseState: Equatable, Sendable {
    case free
    case heldByMe(expires: Date?)
    case heldByOther(expires: Date?)
}

extension SecretDetail {
    func withLease(_ lease: Lease?) -> SecretDetail {
        SecretDetail(
            summary: summary, type: type, values: values, lease: lease, folderPath: folderPath,
            expiresAt: expiresAt, verifiedAt: verifiedAt, nextRotationAt: nextRotationAt
        )
    }
}

/// One secret: its details, the rows of its fields and who has it checked out. Sensitive values are not here; the
/// reveal coordinator holds them.
@MainActor
@Observable
final class SecretDetailModel {
    enum Phase: Equatable {
        case loading
        case loaded(SecretDetail)
        case failed(String)
    }

    private static let logger = Logger(subsystem: "com.therabbithole.app.apple.sneakers-pam", category: "secret")

    let secretID: String
    private(set) var phase = Phase.loading
    private(set) var message: String?
    private(set) var isWorking = false
    private(set) var access = Access.none

    init(secretID: String) {
        self.secretID = secretID
    }

    private var detail: SecretDetail? {
        if case let .loaded(detail) = phase {
            detail
        } else {
            nil
        }
    }

    var fieldRows: [FieldRow] {
        guard let detail, detail.summary.isReadable else { return [] }
        guard let fields = detail.type?.fields else {
            return detail.values.keys.sorted().map { key in
                FieldRow(key: key, label: key.capitalized, isSensitive: false, plainValue: detail.values[key])
            }
        }
        return fields.map { field in
            FieldRow(
                key: field.key,
                label: field.label,
                isSensitive: field.isSensitive,
                plainValue: field.isSensitive ? nil : detail.values[field.key],
                kind: field.fieldKind
            )
        }
    }

    /// Field labels by key, for naming what a version changed.
    var fieldLabels: [String: String] {
        Dictionary(uniqueKeysWithValues: (detail?.type?.fields ?? []).map { ($0.key, $0.label) })
    }

    /// A draft for the edit screen, or nil when I may not change this secret.
    func makeEditModel() -> EditSecretModel? {
        guard canEdit, let detail, let fields = detail.type?.fields else { return nil }
        return EditSecretModel(
            secretID: secretID, name: detail.summary.name, fields: fields, values: detail.values
        )
    }

    func leaseState(userID: String) -> LeaseState {
        guard let lease = detail?.lease else { return .free }
        return lease.userId == userID ? .heldByMe(expires: lease.expiry) : .heldByOther(expires: lease.expiry)
    }

    var canEdit: Bool {
        guard let detail else { return false }
        return access.manage && detail.summary.isReadable
    }

    var lifecycle: SecretLifecycle {
        detail?.lifecycle ?? SecretLifecycle()
    }

    private var isRetired: Bool {
        detail?.summary.retired == true
    }

    var canRotate: Bool {
        access.manage && detail?.type?.supportsRotation == true && !isRetired && !lifecycle.rotationOptOut
    }

    var canRetire: Bool {
        access.manage && detail != nil && !isRetired
    }

    var canReinstate: Bool {
        access.manage && isRetired
    }

    var canToggleHeartbeat: Bool {
        access.manage && detail?.type?.supportsHeartbeat == true && !isRetired
            && lifecycle.heartbeatBlockedReason == nil
    }

    var canToggleRotation: Bool {
        access.manage && detail?.type?.supportsRotation == true && !isRetired
    }

    var canCheckOut: Bool {
        guard let detail else { return false }
        return detail.summary.isReadable && detail.type?.supportsCheckout == true && detail.lease == nil
    }

    func canCheckIn(userID: String) -> Bool {
        detail?.lease?.userId == userID
    }

    func load(_ access: VaultAccess) async {
        do {
            let loaded = try await access.perform { try await access.service.secret(id: self.secretID, $0) }
            self.access = await mine(access)
            phase = .loaded(loaded)
            Self.logger.debug("secret loaded")
        } catch {
            let failure = error as? VaultError ?? .unexpected
            Self.logger.info("secret failed: \(String(describing: failure), privacy: .public)")
            phase = .failed(failure.message)
        }
    }

    /// What I may do here. When the gateway cannot say, I may do nothing, and the screen still opens.
    private func mine(_ access: VaultAccess) async -> Access {
        do {
            return try await access.perform { try await access.service.access(forSecret: self.secretID, $0) }
        } catch {
            Self.logger.info("secret access could not be read")
            return .none
        }
    }

    func rotateNow(_ access: VaultAccess) async {
        await change(access) { try await $0.rotate(secretID: self.secretID, $1) }
    }

    func retire(_ access: VaultAccess) async {
        await change(access) { try await $0.retire(secretID: self.secretID, $1) }
    }

    func reinstate(_ access: VaultAccess) async {
        await change(access) { try await $0.reinstate(secretID: self.secretID, $1) }
    }

    func setHeartbeat(on isOn: Bool, _ access: VaultAccess) async {
        let rotationOff = lifecycle.rotationOptOut
        await change(access) {
            let setting = AutomationSetting(disableRotation: rotationOff, disableHeartbeat: !isOn)
            try await $0.setAutomation(secretID: self.secretID, setting, $1)
        }
    }

    func setRotation(on isOn: Bool, _ access: VaultAccess) async {
        let heartbeatOff = lifecycle.heartbeatOptOut
        await change(access) {
            let setting = AutomationSetting(disableRotation: !isOn, disableHeartbeat: heartbeatOff)
            try await $0.setAutomation(secretID: self.secretID, setting, $1)
        }
    }

    /// Runs one action on the secret, says why if the server refused it, and reads the secret again.
    private func change(
        _ access: VaultAccess,
        _ work: @escaping (VaultServicing, ServerContext) async throws -> Void
    ) async {
        isWorking = true
        message = nil
        defer { isWorking = false }
        do {
            try await access.perform { try await work(access.service, $0) }
        } catch {
            message = (error as? VaultError ?? .unexpected).message
            return
        }
        await load(access)
    }

    func checkOut(_ access: VaultAccess) async {
        guard let detail else { return }
        isWorking = true
        message = nil
        defer { isWorking = false }
        do {
            let lease = try await access.perform { try await access.service.checkout(secretID: self.secretID, $0) }
            phase = .loaded(detail.withLease(lease))
        } catch {
            message = (error as? VaultError ?? .unexpected).message
        }
    }

    func checkIn(_ access: VaultAccess) async {
        guard let detail else { return }
        isWorking = true
        message = nil
        defer { isWorking = false }
        do {
            try await access.perform { try await access.service.checkin(secretID: self.secretID, $0) }
            phase = .loaded(detail.withLease(nil))
        } catch {
            message = (error as? VaultError ?? .unexpected).message
        }
    }
}
