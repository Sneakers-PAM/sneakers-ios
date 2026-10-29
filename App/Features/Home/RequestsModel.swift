// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Observation
import os

/// The Requests and Approvals screens: what is waiting on me, what I asked for, and what was decided. Deciding is
/// confirmed with the device's own check first, and the secret's value never comes into it.
@MainActor
@Observable
final class RequestsModel {
    enum Phase: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    static let notConfirmed = "Couldn't confirm it's you, so nothing was decided."
    static let noPasscode = "Set a device passcode first. Approvals are confirmed with it."

    private static let logger = Logger(subsystem: "com.therabbithole.app.apple.sneakers-pam", category: "requests")

    private let authenticator: Authenticating
    private(set) var phase = Phase.loading
    private(set) var board = RequestBoard(
        RequestsOverview(requests: [], secretNames: [:], secretsIMayApprove: [], people: [:]), for: ""
    )
    private(set) var usesToDecide: [SecretUse] = []
    private(set) var myUses: [SecretUse] = []
    private(set) var message: String?
    private(set) var isWorking = false

    init(authenticator: Authenticating) {
        self.authenticator = authenticator
    }

    /// How many things are waiting on my decision, for a badge.
    var awaitingCount: Int {
        board.awaiting.count + usesToDecide.count
    }

    func load(_ access: VaultAccess) async {
        do {
            let userID = try access.context().session.userID
            let overview = try await access.perform { try await access.service.requestsOverview($0) }
            usesToDecide = try await access.perform { try await access.service.usesToDecide($0) }
            myUses = try await access.perform { try await access.service.myPendingUses($0) }
            board = RequestBoard(overview, for: userID)
            phase = .loaded
        } catch {
            let failure = error as? VaultError ?? .unexpected
            Self.logger.info("requests failed: \(String(describing: failure), privacy: .public)")
            phase = .failed(failure.message)
        }
    }

    func decide(_ requestID: String, approve: Bool, hours: Int, _ access: VaultAccess) async {
        guard await confirmed(approve ? "Approve this request" : "Deny this request") else { return }
        await act(access) {
            try await $0.resolve(requestID: requestID, approve: approve, grantHours: approve ? hours : nil, $1)
        }
    }

    func decideUse(_ use: SecretUse, approve: Bool, _ access: VaultAccess) async {
        guard await confirmed(approve ? "Approve this reveal" : "Deny this reveal") else { return }
        await act(access) { try await $0.decideUse(id: use.id, approve: approve, $1) }
    }

    func comment(_ requestID: String, body: String, _ access: VaultAccess) async {
        let text = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        await act(access) { try await $0.comment(requestID: requestID, body: text, $1) }
    }

    /// Asks the device to check that it is me. A cancelled check is quiet, and any other failure is said.
    private func confirmed(_ reason: String) async -> Bool {
        message = nil
        switch await authenticator.authenticate(reason: reason) {
        case .success: return true
        case .cancelled: return false
        case .failed: message = Self.notConfirmed
        case .notAvailable: message = Self.noPasscode
        }
        return false
    }

    private func act(
        _ access: VaultAccess,
        _ work: @escaping (VaultServicing, ServerContext) async throws -> Void
    ) async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await access.perform { try await work(access.service, $0) }
        } catch {
            message = (error as? VaultError ?? .unexpected).message
            return
        }
        await load(access)
    }
}
