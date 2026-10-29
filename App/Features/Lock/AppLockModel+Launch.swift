// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

extension AppLockModel {
    /// The lock the running app uses: the device's own check and the saved setting.
    static func live(arguments: [String] = CommandLine.arguments) -> AppLockModel {
        #if DEBUG
            if let model = uiTesting(arguments: arguments) {
                return model
            }
        #endif
        return AppLockModel(authenticator: LocalAuthenticator(), settings: UserDefaultsLockSettings())
    }
}

#if DEBUG
    extension AppLockModel {
        /// Launch argument for UI tests that need the lock on and unable to open. Debug builds only.
        static let lockedArgument = "-uiTestingLocked"

        private static func uiTesting(arguments: [String]) -> AppLockModel? {
            if arguments.contains(lockedArgument) {
                return AppLockModel(
                    authenticator: CancellingAuthenticator(),
                    settings: FixedLockSettings(isEnabled: true)
                )
            }
            var testingArguments = [SessionManager.signedInArgument, ServerRegistry.oneServerArgument]
            testingArguments.append(ServerRegistry.emptyServersArgument)
            testingArguments.append(SessionManager.enrolmentRequiredArgument)
            if testingArguments.contains(where: arguments.contains) {
                return AppLockModel(
                    authenticator: CancellingAuthenticator(),
                    settings: FixedLockSettings(isEnabled: false)
                )
            }
            return nil
        }
    }

    /// Always says the person cancelled, so a locked app stays locked.
    private struct CancellingAuthenticator: Authenticating {
        func authenticate(reason _: String) async -> LockResult {
            .cancelled
        }
    }

    private final class FixedLockSettings: LockSettingStoring, @unchecked Sendable {
        private var isEnabled: Bool

        init(isEnabled: Bool) {
            self.isEnabled = isEnabled
        }

        func load() -> Bool {
            isEnabled
        }

        func save(_ isEnabled: Bool) {
            self.isEnabled = isEnabled
        }
    }
#endif
