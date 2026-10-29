// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

@testable import Sneakers_PAM
import Testing

struct ServerSupportPolicyTests {
    private let latest = ReleaseLine(major: 0, minor: 3)
    private let previous = ReleaseLine(major: 0, minor: 2)
    private var policy: ServerSupportPolicy {
        ServerSupportPolicy(supportedLines: [latest, previous])
    }

    @Test func parsesAVersionWithOrWithoutTheV() {
        #expect(ServerVersion(parsing: "v0.2.1") == ServerVersion(major: 0, minor: 2, patch: 1))
        #expect(ServerVersion(parsing: "1.10.4") == ServerVersion(major: 1, minor: 10, patch: 4))
    }

    @Test func ignoresAPreReleaseSuffix() {
        #expect(ServerVersion(parsing: "v0.2.0-rc.3") == ServerVersion(major: 0, minor: 2, patch: 0))
    }

    @Test func refusesTextThatIsNotAVersion() {
        #expect(ServerVersion(parsing: "") == nil)
        #expect(ServerVersion(parsing: "dev") == nil)
        #expect(ServerVersion(parsing: "v1.2") == nil)
    }

    @Test func theLatestReleaseLineIsSupported() {
        #expect(policy.check(ServerVersion(major: 0, minor: 3, patch: 5)) == .supported)
    }

    @Test func theReleaseLineBeforeIsSupported() {
        #expect(policy.check(ServerVersion(major: 0, minor: 2, patch: 0)) == .supported)
    }

    @Test func anOlderServerNeedsAnUpdate() {
        #expect(policy.check(ServerVersion(major: 0, minor: 1, patch: 9)) == .serverTooOld)
    }

    @Test func aNewerServerNeedsAnAppUpdate() {
        #expect(policy.check(ServerVersion(major: 0, minor: 4, patch: 0)) == .appTooOld)
        #expect(policy.check(ServerVersion(major: 1, minor: 0, patch: 0)) == .appTooOld)
    }

    @Test func thisAppReleaseSupportsTheFirstServerRelease() {
        #expect(ServerSupportPolicy.current.check(ServerVersion(major: 0, minor: 1, patch: 0)) == .supported)
    }
}
