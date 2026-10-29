// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Sneakers_PAM
import Testing

@MainActor
struct BrowseModelsTests {
    private let vault = FakeVaultService()

    private func makeAccess() -> VaultAccess {
        VaultAccess(service: vault, context: { .fixture }, onSessionEnded: {})
    }

    private func stats(total: Int = 10) -> SecretStats {
        SecretStats(total: total, expiringSoon: 1, expired: 0, drift: 2)
    }

    // MARK: Dashboard

    @Test func theDashboardStartsLoading() {
        #expect(DashboardModel().phase == .loading)
    }

    @Test func aLoadedDashboardHoldsItsData() async {
        let data = DashboardData(stats: stats(), topSecrets: [.fixture()], leases: [])
        vault.dashboardResult = .success(data)
        let model = DashboardModel()

        await model.load(makeAccess())

        #expect(model.phase == .loaded(data))
        #expect(vault.dashboardCalls == 1)
    }

    @Test func aFailedDashboardSaysWhyAndCanBeRetried() async {
        vault.dashboardResult = .failure(.unreachable)
        let model = DashboardModel()
        await model.load(makeAccess())
        #expect(model.phase == .failed(VaultError.unreachable.message))

        let data = DashboardData(stats: stats(), topSecrets: [], leases: [])
        vault.dashboardResult = .success(data)
        await model.load(makeAccess())

        #expect(model.phase == .loaded(data))
    }

    @Test func aVaultWithNothingInItIsEmpty() async {
        vault.dashboardResult = .success(DashboardData(stats: stats(total: 0), topSecrets: [], leases: []))
        let model = DashboardModel()
        await model.load(makeAccess())

        #expect(model.isEmpty)
    }

    @Test func aVaultWithASecretOrALeaseIsNotEmpty() async {
        vault.dashboardResult = .success(DashboardData(stats: stats(total: 3), topSecrets: [], leases: []))
        let model = DashboardModel()
        await model.load(makeAccess())

        #expect(!model.isEmpty)
    }

    // MARK: Folders

    @Test func foldersLoadIntoATree() async {
        let platform = Folder(id: "1", name: "Platform", parentId: nil, subtreeSecretCount: nil)
        let databases = Folder(id: "2", name: "Databases", parentId: "1", subtreeSecretCount: nil)
        vault.foldersResult = .success([platform, databases])
        let model = FoldersModel()

        await model.load(makeAccess())

        #expect(model.tree.children(of: nil).map(\.name) == ["Platform"])
        #expect(model.tree.children(of: "1").map(\.name) == ["Databases"])
        #expect(model.message == nil)
    }

    @Test func foldersThatCannotLoadSaySo() async {
        vault.foldersResult = .failure(.unreachable)
        let model = FoldersModel()

        await model.load(makeAccess())

        #expect(model.message == VaultError.unreachable.message)
    }

    // MARK: Secrets in a folder

    @Test func aFolderListsItsSecretsAndKnowsTheirMainField() async {
        let contents = FolderContents(secrets: [.fixture(id: "s1", name: "DB admin")], types: [.databaseFixture])
        vault.contentsResult = .success(contents)
        let model = SecretListModel(folderID: "f1")

        await model.load(makeAccess())

        #expect(model.visibleSecrets.map(\.name) == ["DB admin"])
        #expect(model.primaryFieldKey(for: model.visibleSecrets[0]) == "password")
        #expect(vault.contentsCalls == ["f1"])
    }

    @Test func searchFiltersByNameIgnoringCaseAndSpaces() async {
        let secrets = [SecretSummary.fixture(id: "1", name: "DB admin"), .fixture(id: "2", name: "Acme VPN")]
        vault.contentsResult = .success(FolderContents(secrets: secrets, types: []))
        let model = SecretListModel(folderID: "f1")
        await model.load(makeAccess())

        model.search = "  vpn "
        #expect(model.visibleSecrets.map(\.name) == ["Acme VPN"])

        model.search = ""
        #expect(model.visibleSecrets.count == 2)

        model.search = "nothing like it"
        #expect(model.visibleSecrets.isEmpty)
    }

    @Test func aSecretTheUserCannotReadIsListedAsLocked() async {
        let locked = SecretSummary.fixture(id: "9", name: "Vendor key", canRead: false)
        vault.contentsResult = .success(FolderContents(secrets: [locked], types: []))
        let model = SecretListModel(folderID: "f1")

        await model.load(makeAccess())

        #expect(model.visibleSecrets.first?.isReadable == false)
        #expect(model.primaryFieldKey(for: locked) == nil)
    }

    @Test func aFolderThatCannotLoadSaysSo() async {
        vault.contentsResult = .failure(.noAccess)
        let model = SecretListModel(folderID: "f1")

        await model.load(makeAccess())

        #expect(model.message == VaultError.noAccess.message)
        #expect(model.visibleSecrets.isEmpty)
    }
}
