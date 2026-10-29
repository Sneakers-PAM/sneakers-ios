// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

@testable import Sneakers_PAM
import Testing

struct LockContentTests {
    @Test func theLockScreenSaysWhichServerIsBeingUnlocked() {
        #expect(LockContent.subtitle(serverName: "one.example.org") == "Unlock to open one.example.org.")
    }

    @Test func withNoServerItStillSaysWhatIsBeingUnlocked() {
        #expect(LockContent.subtitle(serverName: nil) == "Unlock to open Sneakers-PAM.")
    }

    @Test func theInstructionSaysItIsTheDevicePasscodeNotTheSneakersPassword() {
        #expect(LockContent.instruction == "Use Face ID, Touch ID or your device passcode.")
    }

    @Test func theSystemPromptNamesTheServer() {
        #expect(LockContent.reason(serverName: "one.example.org") == "Unlock Sneakers-PAM for one.example.org")
        #expect(LockContent.reason(serverName: nil) == "Unlock Sneakers-PAM")
    }

    @Test func theSettingSaysDevicePasscode() {
        #expect(LockContent.settingLabel == "Lock with Face ID or device passcode")
    }
}
