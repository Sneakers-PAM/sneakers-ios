// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

/// The list of servers with a switcher, a swipe to remove and an Add server sheet. Used in Account and on the
/// sign-in screen, so a wrong server can be fixed before anyone signs in.
struct ServersSection: View {
    @Environment(ServerRegistry.self) private var registry
    @Environment(SessionManager.self) private var sessions
    @State private var showsAddSheet = false

    var body: some View {
        Section {
            ForEach(registry.entries) { entry in
                Button {
                    registry.select(entry.id)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.name)
                                .foregroundStyle(.primary)
                            Text(entry.version.map { "Release \($0.text)" } ?? "Release checked at sign-in")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if entry.id == registry.activeID {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color("LacesSole"))
                                .accessibilityLabel("Active")
                        }
                    }
                }
            }
            .onDelete { offsets in
                for index in offsets {
                    let id = registry.entries[index].id
                    sessions.forget(id)
                    registry.remove(id)
                }
            }
            Button("Add server", systemImage: "plus") {
                showsAddSheet = true
            }
            .sheet(isPresented: $showsAddSheet) {
                NavigationStack {
                    AddServerView(onAdded: { showsAddSheet = false }, onCancel: { showsAddSheet = false })
                        .navigationBarTitleDisplayMode(.inline)
                }
                .presentationDetents([.large])
            }
        } header: {
            Text("Servers")
        } footer: {
            Text("Each server keeps its own sign-in and data. Swipe a server to remove it.")
        }
    }
}

/// The servers list in a sheet, for the sign-in screen.
struct ServersSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ServersSection()
            }
            .navigationTitle("Servers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
