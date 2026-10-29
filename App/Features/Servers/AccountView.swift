// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

/// The Account section for now: the servers the app knows about, with a switcher and an add sheet.
struct AccountView: View {
    @Environment(ServerRegistry.self) private var registry
    @State private var showsAddSheet = false

    var body: some View {
        NavigationStack {
            List {
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
                            registry.remove(registry.entries[index].id)
                        }
                    }
                    Button("Add server", systemImage: "plus") {
                        showsAddSheet = true
                    }
                } header: {
                    Text("Servers")
                } footer: {
                    Text("Each server keeps its own sign-in and data. Swipe a server to remove it.")
                }
            }
            .navigationTitle("Account")
            .sheet(isPresented: $showsAddSheet) {
                NavigationStack {
                    AddServerView(onAdded: { showsAddSheet = false }, onCancel: { showsAddSheet = false })
                        .navigationBarTitleDisplayMode(.inline)
                }
                .presentationDetents([.large])
            }
        }
    }
}

#Preview {
    AccountView()
        .environment(ServerRegistry(store: UserDefaultsServerStore(), probe: HTTPServerProbe(), policy: .current))
}
