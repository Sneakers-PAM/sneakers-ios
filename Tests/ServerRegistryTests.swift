// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Sneakers_PAM
import Testing

@MainActor
struct ServerRegistryTests {
    private let probe = FakeServerProbe()
    private let store = InMemoryServerStore()

    private func makeRegistry() -> ServerRegistry {
        ServerRegistry(store: store, probe: probe, policy: .current)
    }

    @Test func addsAReachableSupportedServerAndMakesItActive() async {
        probe.answer("one.example.org", version: "v0.1.0")
        let registry = makeRegistry()

        let outcome = await registry.add(input: "one.example.org")

        guard case let .added(entry) = outcome else {
            Issue.record("expected added, got \(outcome)")
            return
        }
        #expect(registry.entries == [entry])
        #expect(registry.activeID == entry.id)
        #expect(registry.active?.url.host == "one.example.org")
    }

    @Test func savesWhatItAdds() async {
        probe.answer("one.example.org", version: "v0.1.2")
        let registry = makeRegistry()
        _ = await registry.add(input: "one.example.org")

        #expect(store.saveCount == 1)
        #expect(store.contents.entries.count == 1)
        #expect(store.contents.activeID == registry.activeID)
    }

    @Test func loadsSavedServersAtStart() throws {
        let entry = try ServerEntry(
            id: UUID(),
            url: ServerURL(input: "saved.example.org"),
            addedAt: Date(timeIntervalSince1970: 0)
        )
        store.contents = ServerList(entries: [entry], activeID: entry.id)

        let registry = makeRegistry()

        #expect(registry.entries == [entry])
        #expect(registry.active == entry)
    }

    @Test func aSecondServerIsAddedAndBecomesActive() async {
        probe.answer("one.example.org", version: "v0.1.0")
        probe.answer("two.example.org", version: "v0.1.3")
        let registry = makeRegistry()
        _ = await registry.add(input: "one.example.org")
        _ = await registry.add(input: "two.example.org")

        #expect(registry.entries.map(\.url.host) == ["one.example.org", "two.example.org"])
        #expect(registry.active?.url.host == "two.example.org")
    }

    @Test func addingTheSameServerAgainSelectsItInsteadOfDuplicating() async {
        probe.answer("one.example.org", version: "v0.1.0")
        probe.answer("two.example.org", version: "v0.1.0")
        let registry = makeRegistry()
        _ = await registry.add(input: "one.example.org")
        _ = await registry.add(input: "two.example.org")

        let outcome = await registry.add(input: "https://One.Example.org/")

        guard case let .alreadyAdded(entry) = outcome else {
            Issue.record("expected alreadyAdded, got \(outcome)")
            return
        }
        #expect(registry.entries.count == 2)
        #expect(registry.activeID == entry.id)
    }

    @Test func anInvalidAddressIsRefusedWithoutAskingTheNetwork() async {
        let registry = makeRegistry()

        let outcome = await registry.add(input: "http://one.example.org")

        #expect(outcome == .invalidAddress(.notSecure))
        #expect(probe.probedHosts.isEmpty)
        #expect(registry.entries.isEmpty)
        #expect(store.saveCount == 0)
    }

    @Test func anUnreachableServerIsNotSaved() async {
        let registry = makeRegistry()

        let outcome = await registry.add(input: "down.example.org")

        #expect(outcome == .unreachable)
        #expect(registry.entries.isEmpty)
        #expect(store.saveCount == 0)
    }

    @Test func somethingThatIsNotASneakersServerIsNotSaved() async {
        probe.answer("web.example.org", version: nil, looksLikeSneakers: false)
        probe.answer("odd.example.org", version: "dev")
        let registry = makeRegistry()

        #expect(await registry.add(input: "web.example.org") == .notASneakersServer)
        #expect(await registry.add(input: "odd.example.org") == .notASneakersServer)
        #expect(registry.entries.isEmpty)
    }

    @Test func aServerThatSharesNoVersionIsAddedUnverified() async {
        probe.answer("quiet.example.org", version: nil, looksLikeSneakers: true)
        let registry = makeRegistry()

        let outcome = await registry.add(input: "quiet.example.org")

        guard case let .addedUnverified(entry) = outcome else {
            Issue.record("expected addedUnverified, got \(outcome)")
            return
        }
        #expect(entry.version == nil)
        #expect(registry.entries == [entry])
        #expect(registry.activeID == entry.id)
        #expect(store.contents.entries == [entry])
    }

    @Test func aServerThatSharesItsVersionKeepsIt() async {
        probe.answer("one.example.org", version: "v0.1.4")
        let registry = makeRegistry()

        _ = await registry.add(input: "one.example.org")

        #expect(registry.entries.first?.version == ServerVersion(major: 0, minor: 1, patch: 4))
    }

    @Test func anOlderServerIsNotSavedAndSaysWhy() async {
        probe.answer("old.example.org", version: "v0.0.9")
        let registry = makeRegistry()

        let outcome = await registry.add(input: "old.example.org")

        #expect(outcome == .serverTooOld(ServerVersion(major: 0, minor: 0, patch: 9)))
        #expect(registry.entries.isEmpty)
    }

    @Test func aNewerServerIsNotSavedAndSaysWhy() async {
        probe.answer("new.example.org", version: "v9.0.0")
        let registry = makeRegistry()

        let outcome = await registry.add(input: "new.example.org")

        #expect(outcome == .appTooOld(ServerVersion(major: 9, minor: 0, patch: 0)))
        #expect(registry.entries.isEmpty)
    }

    @Test func selectingAServerMakesItActive() async {
        probe.answer("one.example.org", version: "v0.1.0")
        probe.answer("two.example.org", version: "v0.1.0")
        let registry = makeRegistry()
        _ = await registry.add(input: "one.example.org")
        _ = await registry.add(input: "two.example.org")
        let first = registry.entries[0]

        registry.select(first.id)

        #expect(registry.activeID == first.id)
        #expect(store.contents.activeID == first.id)
    }

    @Test func removingTheActiveServerFallsBackToAnother() async {
        probe.answer("one.example.org", version: "v0.1.0")
        probe.answer("two.example.org", version: "v0.1.0")
        let registry = makeRegistry()
        _ = await registry.add(input: "one.example.org")
        _ = await registry.add(input: "two.example.org")
        let active = registry.entries[1]

        registry.remove(active.id)

        #expect(registry.entries.map(\.url.host) == ["one.example.org"])
        #expect(registry.active?.url.host == "one.example.org")
    }

    @Test func removingTheLastServerLeavesNoneActive() async {
        probe.answer("one.example.org", version: "v0.1.0")
        let registry = makeRegistry()
        _ = await registry.add(input: "one.example.org")

        registry.remove(registry.entries[0].id)

        #expect(registry.entries.isEmpty)
        #expect(registry.activeID == nil)
    }

    @Test func removingAnUnknownServerChangesNothing() async {
        probe.answer("one.example.org", version: "v0.1.0")
        let registry = makeRegistry()
        _ = await registry.add(input: "one.example.org")
        let saves = store.saveCount

        registry.remove(UUID())

        #expect(registry.entries.count == 1)
        #expect(store.saveCount == saves)
    }
}
