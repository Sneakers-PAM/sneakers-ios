// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// The top-level sections of the app, in the order the Laces mobile design shows them.
nonisolated enum AppSection: String, CaseIterable, Identifiable {
    case home
    case folders
    case requests
    case approvals
    case account

    static let initial: AppSection = .home

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .home: "Home"
        case .folders: "Folders"
        case .requests: "Requests"
        case .approvals: "Approvals"
        case .account: "Account"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .folders: "folder"
        case .requests: "tray"
        case .approvals: "checkmark.shield"
        case .account: "person.crop.circle"
        }
    }
}
