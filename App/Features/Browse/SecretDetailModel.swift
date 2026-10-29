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
                plainValue: field.isSensitive ? nil : detail.values[field.key]
            )
        }
    }

    func leaseState(userID: String) -> LeaseState {
        guard let lease = detail?.lease else { return .free }
        return lease.userId == userID ? .heldByMe(expires: lease.expiry) : .heldByOther(expires: lease.expiry)
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
            phase = .loaded(loaded)
            Self.logger.debug("secret loaded")
        } catch {
            let failure = error as? VaultError ?? .unexpected
            Self.logger.info("secret failed: \(String(describing: failure), privacy: .public)")
            phase = .failed(failure.message)
        }
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
