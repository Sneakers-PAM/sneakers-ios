// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import os

/// Asks a server who it is without signing in. It reads the Sneakers-Version header from /livez where the
/// server exposes it. A server that does not (behind a front end that hides /livez) is still recognised
/// by a healthy /healthz, and its version is checked after sign-in.
nonisolated struct HTTPServerProbe: ServerProbing {
    private static let logger = Logger(subsystem: "com.therabbithole.app.apple.sneakers-pam", category: "servers")
    private static let timeout: TimeInterval = 5

    var session: URLSession = .shared

    func probe(_ url: ServerURL) async throws -> ServerProbeResult {
        let livez = try await fetch(path: "/livez", for: url)
        if let version = Self.version(from: livez.response) {
            Self.logger.debug("probe: server announced a version")
            return ServerProbeResult(versionText: version, looksLikeSneakers: true)
        }

        let healthz = try await fetch(path: "/healthz", for: url)
        let healthy = Self.looksHealthy(status: healthz.response.statusCode, body: healthz.body)
        Self.logger.debug("probe: no version announced, health check \(healthy ? "ok" : "not ok", privacy: .public)")
        return ServerProbeResult(versionText: nil, looksLikeSneakers: healthy)
    }

    private func fetch(path: String, for server: ServerURL) async throws -> (response: HTTPURLResponse, body: Data) {
        guard let address = Self.url(path: path, for: server) else { throw ServerProbeError.unreachable }
        var request = URLRequest(
            url: address,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: Self.timeout
        )
        request.httpMethod = "GET"

        let started = Date()
        do {
            let (body, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ServerProbeError.unreachable }
            let seconds = Date().timeIntervalSince(started)
            let status = http.statusCode
            Self.logger.debug("probe \(path, privacy: .public): \(status) in \(seconds, format: .fixed(precision: 2))s")
            return (http, body)
        } catch {
            Self.logger.info("probe \(path, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            throw ServerProbeError.unreachable
        }
    }

    static func url(path: String, for server: ServerURL) -> URL? {
        URL(string: server.absoluteString + path)
    }

    static func version(from response: HTTPURLResponse) -> String? {
        response.value(forHTTPHeaderField: "Sneakers-Version")
    }

    static func looksHealthy(status: Int, body: Data) -> Bool {
        guard status == 200 else { return false }
        let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
        return object?["status"] as? String == "ok"
    }
}
