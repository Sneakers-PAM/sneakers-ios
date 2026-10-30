// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

/// Home: what is checked out to me, the four counts and the most accessed secrets.
struct HomeView: View {
    @Environment(VaultAccess.self) private var access
    @State private var model = DashboardModel()
    @Binding var scan: ScanRequest?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Home")
                .navigationDestination(for: SecretRoute.self) { route in
                    SecretDetailView(secretID: route.id, title: route.name)
                }
                .toolbar {
                    ScanToolbarButton(presenting: $scan, server: (try? access.context().server))
                    AccountToolbarButton()
                }
        }
        .task { await model.load(access) }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading:
            SneakerLoaderView(size: 96)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("homeLoading")
        case let .failed(message):
            ContentUnavailableView {
                Label("Couldn't load Home", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try again") { Task { await model.load(access) } }
                    .accessibilityIdentifier("homeRetry")
            }
        case let .loaded(data):
            if model.isEmpty {
                ContentUnavailableView(
                    "Nothing here yet",
                    systemImage: "tray",
                    description: Text("Secrets you can read will show up here.")
                )
                .accessibilityIdentifier("homeEmpty")
            } else {
                loaded(data)
            }
        }
    }

    private func loaded(_ data: DashboardData) -> some View {
        List {
            if !data.leases.isEmpty {
                Section("Checked out to you") {
                    ForEach(data.leases, id: \.lease.id) { held in
                        NavigationLink(value: SecretRoute(id: held.lease.secretId, name: held.secretName)) {
                            LeaseRow(held: held)
                        }
                    }
                }
                .accessibilityIdentifier("homeLeases")
            }
            Section {
                StatTiles(stats: data.stats)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            if !data.topSecrets.isEmpty {
                Section("Most accessed") {
                    ForEach(data.topSecrets) { secret in
                        NavigationLink(value: SecretRoute(id: secret.id, name: secret.name)) {
                            LabeledContent(secret.name, value: "\(secret.viewCount ?? 0)")
                        }
                    }
                }
                .accessibilityIdentifier("homeTop")
            }
        }
        .refreshable { await model.load(access) }
    }
}

/// Where a secret screen is pushed to from a list.
struct SecretRoute: Hashable {
    let id: String
    let name: String
}

private struct LeaseRow: View {
    let held: LeaseWithName

    var body: some View {
        HStack {
            Text(held.secretName)
            Spacer()
            if let expiry = held.lease.expiry {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let left = LeaseCountdown.remaining(until: expiry, now: context.date)
                    Text(LeaseCountdown.text(remaining: left))
                        .monospacedDigit()
                        .foregroundStyle(left < 300 ? Color.red : Color.secondary)
                        .accessibilityLabel("Time left \(LeaseCountdown.text(remaining: left))")
                }
            }
        }
    }
}

private struct StatTiles: View {
    /// Tiles are all one size: four across a wide screen, two by two on a phone.
    private static let tileHeight: CGFloat = 96

    let stats: SecretStats
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: sizeClass == .regular ? 4 : 2)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            tile("accessible", "Secrets", stats.total, "key")
            tile("expiring", "Expiring soon", stats.expiringSoon, "clock")
            tile("expired", "Expired", stats.expired, "exclamationmark.circle")
            tile("drift", "Drift", stats.drift, "arrow.triangle.2.circlepath")
        }
        .padding(.vertical, 4)
    }

    private func tile(_ id: String, _ title: String, _ value: Int, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text("\(value)")
                .font(.title.bold())
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, minHeight: Self.tileHeight, alignment: .topLeading)
        .padding(14)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("homeTile.\(id)")
    }
}
