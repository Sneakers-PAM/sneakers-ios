# sneakers-ios 🕊️

> 🧭 Sneakers iOS app (Swift)

## ✨ What it does today

- 🔐 **Sign in:** a username and password, then an authenticator or emailed code, against your own Sneakers server. Nothing in the app shows until you are signed in.
- 🗝 **Device-only sessions:** each server's session lives in the Keychain on this device, locked while the device is, and never synced to iCloud.
- 🌐 **Several servers:** add more than one, check each one's release, and switch between them.
- 🔒 **App lock:** Face ID, Touch ID or the passcode on launch and after a short time out of sight, with a cover over the app switcher.
- 🛡 **Second factor setup:** scan a QR code or type a key, and the app asks for it when the server requires one.
- 🏠 **Home:** what you have checked out with a live countdown, the four counts, and the most accessed secrets.
- 📁 **Folders and secrets:** browse the folder tree, filter a folder by name, open a secret, and check it out or in. On an iPad the folders, the list and the secret sit side by side, and Account is a toolbar button.
- 👁 **Reveal and copy:** a sensitive value is shown or copied only after the server agrees, asking for a fresh code when it wants one. Revealed values hide after 20 seconds, on lock and in the background. A copy stays on this device and clears after 60 seconds.
- ✏️ **Edit a secret:** change its name and fields with a control for each kind of field. Only what changed is sent, and a sensitive value you type is cleared once it is saved.
- 🕘 **History:** every saved version with who changed it and when, reading an old value through the same audited reveal, and restoring a version.
- 💓 **Heartbeat and rotation:** whether a secret's target still accepts the stored value, when it was last checked, rotate now, automatic checking and rotation switches, and retire or restore a secret.
- 📂 **Create and move:** make folders and secrets, rename a folder, and move a secret or folder, with a request when the vault needs a site admin's approval.
- 📨 **Requests and approvals:** ask for access to a secret you can see but not read, follow what you asked for, and approve or deny what waits on you, each confirmed with Face ID, Touch ID or the device passcode first. A badge on Approvals shows how many are waiting, and both screens refresh while they are open.
- ⏳ **Reveals that need approval:** a reveal the vault holds shows a waiting state with a countdown, can be cancelled, and the value is read once it is approved. It is never read before then.
- 👥 **Who has access:** the rules for a secret or folder, including the ones from folders above, and for people who may change them, setting each cell to allow, deny or blank and adding a person.
- 🎨 **Laces design:** the brand icon, the opening screen and the brand fonts.

Passkey and single sign-on sign-in are still to come.

## ▶️ Run it

### Before you start

- Xcode 27 with the iOS 27 simulators, and SwiftLint and SwiftFormat for the checks (`brew install swiftlint swiftformat`).
- A Sneakers server you can reach over https. The app never connects without TLS.
- The app runs on the simulators only for now. Device builds need an Apple developer team.

### Steps

1. Open `Sneakers-PAM.xcodeproj` in Xcode and pick the `Sneakers-PAM` scheme with an iPhone or iPad simulator.
2. Run it. On a new install it asks for your server's address, then signs you in.
3. Run the tests from a terminal:

```bash
xcodebuild test -project Sneakers-PAM.xcodeproj -scheme Sneakers-PAM \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

## 🛠 Develop

```bash
task lint     # SwiftLint and SwiftFormat check
task format   # apply SwiftFormat
task test     # swift test for a package, xcodebuild test for an app
task license  # check Apache-2.0 headers (golic)
```

## 🙏 Acknowledgements

Sneakers-PAM was originally written by [@Bugs5382](https://github.com/Bugs5382).

## ⚖️ License

Apache-2.0 (c) 2026 The Sneakers-PAM Authors
