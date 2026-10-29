// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// Builds the vault access and the reveal coordinator the app shares, from the active server and its session.
@MainActor
enum VaultEnvironment {
    static func make(
        registry: ServerRegistry,
        sessions: SessionManager,
        arguments: [String] = CommandLine.arguments
    ) -> (access: VaultAccess, reveal: RevealCoordinator) {
        let access = VaultAccess(
            service: service(for: arguments),
            context: {
                guard let server = registry.active, let session = sessions.session(for: server.id) else { return nil }
                return ServerContext(server: server.url, session: session)
            },
            onSessionEnded: {
                Task { @MainActor in
                    if let server = registry.active {
                        await sessions.refresh(server)
                    }
                }
            }
        )
        let reveal = RevealCoordinator(access: access, auth: auth(for: arguments), clipboard: SystemClipboard())
        return (access, reveal)
    }

    /// The check before an approval. Debug builds in the UI tests have nobody to look at the phone, so it passes.
    static func authenticator(arguments: [String] = CommandLine.arguments) -> Authenticating {
        #if DEBUG
            if arguments.contains(SessionManager.signedInArgument) {
                return AlwaysSucceeds()
            }
        #endif
        return LocalAuthenticator()
    }

    private static func service(for arguments: [String]) -> VaultServicing {
        #if DEBUG
            if arguments.contains(SessionManager.signedInArgument) {
                return DemoVaultService()
            }
        #endif
        return HTTPVaultService()
    }

    private static func auth(for arguments: [String]) -> AuthServicing {
        #if DEBUG
            if arguments.contains(SessionManager.signedInArgument) {
                return OfflineAuthService()
            }
        #endif
        return HTTPAuthService()
    }
}

#if DEBUG
    private struct AlwaysSucceeds: Authenticating {
        func authenticate(reason _: String) async -> LockResult {
            .success
        }
    }
#endif
