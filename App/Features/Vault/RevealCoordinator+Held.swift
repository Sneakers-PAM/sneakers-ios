// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import os

private let heldLogger = Logger(subsystem: "com.therabbithole.app.apple.sneakers-pam", category: "reveal")

/// A reveal the vault holds for approval: ask for it to be held, wait while someone decides, and read the value once
/// it is approved. Nothing is ever read before then, and the value goes through the same `finish` as any reveal.
extension RevealCoordinator {
    /// One run id per secret on screen, so the reveals one visit raises are decided together.
    func runID(for secretID: String) -> String {
        if let existing = runIDs[secretID] {
            return existing
        }
        let made = "ios_" + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        runIDs[secretID] = made
        return made
    }

    func hold(_ action: PendingReveal) async {
        let key: RevealKey
        switch action {
        case let .show(asked), let .copy(asked): key = asked
        case .restore:
            notice = VaultError.approvalRequired.message
            return
        }
        guard key.versionNo == nil else {
            notice = VaultError.approvalRequired.message
            return
        }
        let run = runID(for: key.secretID)
        do {
            let use = try await access.perform { try await self.access.service.prepareReveal(key, runID: run, $0) }
            heldLogger.info("a reveal is held for approval")
            held[key] = use
            if use.isApproved {
                await collect(action, key: key)
            } else {
                startPolling(action, key: key)
            }
        } catch let error as VaultError {
            notice = error.message
        } catch {
            notice = VaultError.unexpected.message
        }
    }

    func cancelHeld(_ key: RevealKey) {
        heldTasks[key]?.cancel()
        heldTasks[key] = nil
        held[key] = nil
    }

    private func startPolling(_ action: PendingReveal, key: RevealKey) {
        heldTasks[key]?.cancel()
        heldTasks[key] = Task { [pollEvery] in
            while !Task.isCancelled, held[key] != nil {
                guard await (try? Task.sleep(for: pollEvery)) != nil, held[key] != nil else { return }
                if let use = held[key], Date() >= use.expiresAt {
                    cancelHeld(key)
                    notice = "The approval request expired. Ask again."
                    return
                }
                if await collect(action, key: key) {
                    return
                }
            }
        }
    }

    /// Reads an approved value. True once the wait is over, whether it ended in a value or a refusal.
    @discardableResult
    private func collect(_ action: PendingReveal, key: RevealKey) async -> Bool {
        guard let use = held[key] else { return true }
        do {
            let value = try await access.perform { try await self.access.service.redeemReveal(useID: use.id, $0) }
            cancelHeld(key)
            finish(action, value: value)
            return true
        } catch VaultError.approvalPending {
            return false
        } catch let error as VaultError {
            cancelHeld(key)
            notice = error.message
            return true
        } catch {
            cancelHeld(key)
            notice = VaultError.unexpected.message
            return true
        }
    }
}
