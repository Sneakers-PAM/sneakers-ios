// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Observation
import os

/// What happened when the person tried to add a server.
nonisolated enum AddServerOutcome: Equatable, Sendable {
    case added(ServerEntry)
    /// The server is a Sneakers server but did not share its release, so the app checks it after sign-in.
    case addedUnverified(ServerEntry)
    case alreadyAdded(ServerEntry)
    case invalidAddress(ServerURL.Failure)
    case unreachable
    case notASneakersServer
    case serverTooOld(ServerVersion)
    case appTooOld(ServerVersion)
}

/// The servers the app knows about and which one is active. A server is only saved after it answered
/// as a Sneakers server this app release supports.
@MainActor
@Observable
final class ServerRegistry {
    private static let logger = Logger(subsystem: "com.therabbithole.app.apple.sneakers-pam", category: "servers")

    private(set) var entries: [ServerEntry]
    private(set) var activeID: UUID?

    private let store: ServerStoring
    private let probe: ServerProbing
    private let policy: ServerSupportPolicy
    private let makeID: () -> UUID
    private let now: () -> Date

    var active: ServerEntry? {
        entries.first { $0.id == activeID }
    }

    init(
        store: ServerStoring,
        probe: ServerProbing,
        policy: ServerSupportPolicy,
        makeID: @escaping () -> UUID = UUID.init,
        now: @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.probe = probe
        self.policy = policy
        self.makeID = makeID
        self.now = now

        let saved = store.load()
        entries = saved.entries
        activeID = saved.entries.contains { $0.id == saved.activeID } ? saved.activeID : saved.entries.first?.id
        Self.logger.info("loaded \(saved.entries.count) saved servers")
    }

    func add(input: String) async -> AddServerOutcome {
        let url: ServerURL
        do {
            url = try ServerURL(input: input)
        } catch {
            let failure = error as? ServerURL.Failure ?? .malformed
            Self.logger.debug("add server refused: bad address \(String(describing: failure))")
            return .invalidAddress(failure)
        }

        if let existing = entries.first(where: { $0.url == url }) {
            select(existing.id)
            Self.logger.debug("add server: already added")
            return .alreadyAdded(existing)
        }

        let result: ServerProbeResult
        do {
            result = try await probe.probe(url)
        } catch {
            Self.logger.info("add server: unreachable")
            return .unreachable
        }

        guard let text = result.versionText else {
            guard result.looksLikeSneakers else {
                Self.logger.info("add server: did not answer like a Sneakers server")
                return .notASneakersServer
            }
            let entry = append(url: url, version: nil)
            Self.logger.info("added server \(entry.id.uuidString, privacy: .public) without a version")
            return .addedUnverified(entry)
        }
        guard let version = ServerVersion(parsing: text) else {
            Self.logger.info("add server: answered with a version that is not a release")
            return .notASneakersServer
        }

        switch policy.check(version) {
        case .serverTooOld:
            Self.logger.info("add server: server release is older than this app supports")
            return .serverTooOld(version)
        case .appTooOld:
            Self.logger.info("add server: server release is newer than this app supports")
            return .appTooOld(version)
        case .supported:
            let entry = append(url: url, version: version)
            Self.logger.info("added server \(entry.id.uuidString, privacy: .public)")
            return .added(entry)
        }
    }

    private func append(url: ServerURL, version: ServerVersion?) -> ServerEntry {
        let entry = ServerEntry(id: makeID(), url: url, addedAt: now(), version: version)
        entries.append(entry)
        activeID = entry.id
        persist()
        return entry
    }

    func select(_ id: UUID) {
        guard entries.contains(where: { $0.id == id }), activeID != id else { return }
        activeID = id
        persist()
        Self.logger.debug("selected server \(id.uuidString, privacy: .public)")
    }

    func remove(_ id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries.remove(at: index)
        if activeID == id {
            activeID = entries.first?.id
        }
        persist()
        Self.logger.info("removed server \(id.uuidString, privacy: .public)")
    }

    private func persist() {
        store.save(ServerList(entries: entries, activeID: activeID))
    }
}
