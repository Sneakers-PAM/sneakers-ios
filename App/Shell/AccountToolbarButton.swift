// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

/// On a wide screen the tab bar has no room for Account, so every section carries this button instead.
struct AccountToolbarButton: ToolbarContent {
    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            AccountSheetButton()
        }
    }
}

private struct AccountSheetButton: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showsAccount = false

    var body: some View {
        if sizeClass == .regular {
            Button {
                showsAccount = true
            } label: {
                Label("Account", systemImage: AppSection.account.systemImage)
            }
            .accessibilityIdentifier("accountButton")
            .sheet(isPresented: $showsAccount) {
                AccountView()
            }
        }
    }
}
