// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// Which server and which signed-in session a request is for.
nonisolated struct ServerContext: Sendable {
    let server: ServerURL
    let session: AuthenticatedSession
}

nonisolated struct FolderContents: Equatable, Sendable {
    let secrets: [SecretSummary]
    let types: [SecretType]
}

/// The edits to a secret: a new name, and the fields whose values changed. Anything not listed stays as it is.
nonisolated struct SecretChange: Equatable, Sendable {
    var name: String?
    var fields: [String: String]
}

/// A secret to create: its name, where it goes, its type and the values of its fields.
nonisolated struct NewSecret: Equatable, Sendable {
    var name: String
    var folderID: String
    var typeID: String
    var fields: [String: String]
}

/// A move that needs a site admin's approval, with why.
nonisolated struct MoveRequest: Equatable, Sendable {
    enum Subject: Equatable, Sendable {
        case secret(id: String, name: String)
        case folder(id: String, name: String)
    }

    var subject: Subject
    var destinationID: String
    var destinationName: String
    var reason: String
}

/// Someone a rule can be about.
nonisolated struct Person: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let username: String
}

/// Reads and acts on the vault through the gateway. The real one calls the network; tests fake it.
nonisolated protocol VaultServicing: Sendable {
    func dashboard(_ context: ServerContext) async throws -> DashboardData
    func folders(_ context: ServerContext) async throws -> [Folder]
    func contents(ofFolder folderID: String, _ context: ServerContext) async throws -> FolderContents
    func secret(id: String, _ context: ServerContext) async throws -> SecretDetail
    func reveal(secretID: String, fieldKey: String, _ context: ServerContext) async throws -> String
    func checkout(secretID: String, _ context: ServerContext) async throws -> Lease
    func checkin(secretID: String, _ context: ServerContext) async throws
    func access(forFolder folderID: String, _ context: ServerContext) async throws -> Access
    func access(forSecret secretID: String, _ context: ServerContext) async throws -> Access
    func update(secretID: String, _ change: SecretChange, _ context: ServerContext) async throws
    func rotate(secretID: String, _ context: ServerContext) async throws
    func retire(secretID: String, _ context: ServerContext) async throws
    func reinstate(secretID: String, _ context: ServerContext) async throws
    func setAutomation(secretID: String, _ setting: AutomationSetting, _ context: ServerContext) async throws
    func ruleset(forSecret secretID: String, _ context: ServerContext) async throws -> Ruleset
    func ruleset(forFolder folderID: String, _ context: ServerContext) async throws -> Ruleset
    func saveRules(forSecret secretID: String, _ rules: [AccessRule], _ context: ServerContext) async throws
    func saveRules(forFolder folderID: String, _ update: RulesUpdate, _ context: ServerContext) async throws
    func searchPeople(_ query: String, _ context: ServerContext) async throws -> [Person]
    func createFolder(parentID: String?, name: String, _ context: ServerContext) async throws -> Folder
    func renameFolder(id: String, name: String, _ context: ServerContext) async throws
    func moveFolder(id: String, to parentID: String?, _ context: ServerContext) async throws
    func moveSecret(id: String, to folderID: String, _ context: ServerContext) async throws
    func requestMove(_ request: MoveRequest, _ context: ServerContext) async throws
    func secretTypes(_ context: ServerContext) async throws -> [SecretType]
    func createSecret(_ secret: NewSecret, _ context: ServerContext) async throws -> String
    func requestsOverview(_ context: ServerContext) async throws -> RequestsOverview
    func resolve(requestID: String, approve: Bool, grantHours: Int?, _ context: ServerContext) async throws
    func comment(requestID: String, body: String, _ context: ServerContext) async throws
    func usesToDecide(_ context: ServerContext) async throws -> [SecretUse]
    func myPendingUses(_ context: ServerContext) async throws -> [SecretUse]
    func decideUse(id: String, approve: Bool, _ context: ServerContext) async throws
    func requestAccess(secretID: String, reason: String, _ context: ServerContext) async throws
    func prepareReveal(_ key: RevealKey, runID: String, _ context: ServerContext) async throws -> HeldReveal
    func redeemReveal(useID: String, _ context: ServerContext) async throws -> String
    func versions(secretID: String, _ context: ServerContext) async throws -> [SecretVersion]
    /// An earlier version's value: the key names the secret, the field and the version.
    func revealVersion(_ key: RevealKey, _ context: ServerContext) async throws -> String
    func restore(secretID: String, versionNo: Int, _ context: ServerContext) async throws
}

nonisolated enum VaultError: Error, Equatable, Sendable {
    case noAccess
    case stepUpRequired
    case approvalRequired
    case approvalPending
    case checkedOut
    case rotationInProgress
    case rotationNotSupported
    case rotationOptedOut
    case selfApproval
    case notApprover
    case noApprover
    case alreadyDecided
    case notSiteAdmin
    case notFolderOwner
    case recoveryRoleRequired
    case retired
    case leaseHeld
    case notHolder
    case checkoutNotAllowed
    case notFound
    case sessionEnded
    case unreachable
    case unexpected

    /// What to tell the person. It never repeats the server's own wording.
    var message: String {
        switch self {
        case .noAccess: "You don't have access to that."
        case .stepUpRequired: "Confirm it's you with a code to continue."
        case .approvalRequired: "This secret needs approval before it can be revealed."
        case .approvalPending: "Still waiting for approval."
        case .checkedOut: "This secret is checked out, so it can't be changed until it is checked in."
        case .rotationInProgress: "A rotation of this secret is running. Try again when it has finished."
        case .rotationNotSupported: "This kind of secret can't be rotated."
        case .rotationOptedOut: "Rotation is switched off for this secret."
        case .selfApproval: "You can't approve your own request."
        case .notApprover: "You aren't one of the approvers for this."
        case .noApprover: "Nobody is set up to approve this."
        case .alreadyDecided: "That request has already been decided."
        case .notSiteAdmin: "Only a site admin can do that."
        case .notFolderOwner: "Only an owner of the folder can do that."
        case .recoveryRoleRequired: "Reading or restoring an earlier version needs the recovery role."
        case .retired: "This secret is retired."
        case .leaseHeld: "Someone else has this checked out."
        case .notHolder: "Only the person who checked it out can check it in."
        case .checkoutNotAllowed: "This kind of secret can't be checked out."
        case .notFound: "That secret isn't available."
        case .sessionEnded: "Your session ended. Sign in again."
        case .unreachable: "Couldn't reach the server. Check your connection and try again."
        case .unexpected: "Something went wrong. Try again."
        }
    }

    /// Maps the gateway's GraphQL error code and reason, which are stable, never its message text. A known reason wins,
    /// and anything else falls back to the code.
    init(code: String, reason: String?) {
        if let reason, let known = Self.byReason[reason] {
            self = known
        } else {
            self = Self.byCode[code] ?? .unexpected
        }
    }

    private static let byReason: [String: VaultError] = {
        var table: [String: VaultError] = [:]
        table["CHECKIN_NOT_HOLDER"] = .notHolder
        table["STEP_UP_REQUIRED"] = .stepUpRequired
        table["APPROVAL_REQUIRED"] = .approvalRequired
        table["RECOVERY_ROLE_REQUIRED"] = .recoveryRoleRequired
        table["RETIRED"] = .retired
        table["CHECKOUT_LEASE_HELD"] = .leaseHeld
        table["CHECKOUT_TYPE_DISABLED"] = .checkoutNotAllowed
        table["ROTATION_IN_PROGRESS"] = .rotationInProgress
        table["ROTATION_NOT_SUPPORTED"] = .rotationNotSupported
        table["ROTATION_OPTED_OUT"] = .rotationOptedOut
        table["SELF_APPROVAL"] = .selfApproval
        table["NOT_APPROVER"] = .notApprover
        table["NO_APPROVER"] = .noApprover
        table["REQUEST_NOT_PENDING"] = .alreadyDecided
        table["NOT_SITE_ADMIN"] = .notSiteAdmin
        table["NOT_FOLDER_OWNER"] = .notFolderOwner
        return table
    }()

    private static let byCode: [String: VaultError] = {
        var table: [String: VaultError] = [:]
        table["PERMISSION_DENIED"] = .noAccess
        table["NOT_FOUND"] = .notFound
        table["UNAUTHENTICATED"] = .sessionEnded
        table["UNAVAILABLE"] = .unreachable
        table["DEADLINE_EXCEEDED"] = .unreachable
        return table
    }()
}

extension VaultError {
    /// The same refusal when what was asked was a change to a secret. A lease on it, mine or anyone's, blocks the
    /// change, and the checkout wording ("someone else has it") would be wrong then.
    var forAChange: VaultError {
        self == .leaseHeld ? .checkedOut : self
    }
}
