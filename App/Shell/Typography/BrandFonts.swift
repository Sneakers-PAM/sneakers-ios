// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import CoreText
import os
import UIKit

/// The three Laces typefaces, all under the SIL Open Font License. They live in the asset catalog as data. At launch
/// each is written once to the caches folder and registered by file, which is what exposes a variable font's named
/// weights and keeps Dynamic Type scaling.
nonisolated enum BrandFonts {
    private static let logger = Logger(subsystem: "com.therabbithole.app.apple.sneakers-pam", category: "fonts")

    /// Bricolage Grotesque: display and titles.
    static let displayExtraBold = "BricolageGrotesque-96ptExtraBold_ExtraBold"
    static let displayBold = "BricolageGrotesque-96ptExtraBold_Bold"
    /// Atkinson Hyperlegible: the interface.
    static let text = "AtkinsonHyperlegible-Regular"
    static let textBold = "AtkinsonHyperlegible-Bold"
    /// JetBrains Mono: values, code and hashes.
    static let mono = "JetBrainsMono-Regular"
    static let monoBold = "JetBrainsMonoRoman-Bold"

    private static let bricolage = "BricolageGrotesque"
    private static let jetBrains = "JetBrainsMono"
    private static let atkinsonRegular = "AtkinsonHyperlegible-Regular"
    private static let atkinsonBold = "AtkinsonHyperlegible-Bold"

    /// The data assets that hold the font files.
    static let assetNames = [bricolage, jetBrains, atkinsonRegular, atkinsonBold]

    /// The licence texts that travel with the fonts.
    static let licenceAssetNames = ["FontLicenseBricolage", "FontLicenseAtkinson", "FontLicenseJetBrains"]

    /// Every style name the app uses, so a test can check they all resolve.
    static let styleNames = [displayExtraBold, displayBold, text, textBold, mono, monoBold]

    /// Registers every font with the system. Returns the names of any that could not be registered. Registering a
    /// font that is already registered is not a failure, so this is safe to call again.
    @discardableResult
    static func registerAll() -> [String] {
        guard let folder = fontFolder() else { return assetNames }
        return assetNames.filter { !register($0, in: folder) }
    }

    private static func fontFolder() -> URL? {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            logger.error("there is no caches folder to keep the fonts in")
            return nil
        }
        let folder = caches.appending(path: "BrandFonts", directoryHint: .isDirectory)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            return folder
        } catch {
            logger.error("could not create the font folder: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private static func register(_ name: String, in folder: URL) -> Bool {
        guard let asset = NSDataAsset(name: name) else {
            logger.error("font asset \(name, privacy: .public) is missing")
            return false
        }
        let file = folder.appending(path: name + ".ttf")
        let existing = (try? Data(contentsOf: file))?.count
        if existing != asset.data.count {
            do {
                try asset.data.write(to: file, options: .atomic)
            } catch {
                let reason = error.localizedDescription
                logger.error("could not write font \(name, privacy: .public): \(reason, privacy: .public)")
                return false
            }
        }

        var error: Unmanaged<CFError>?
        guard !CTFontManagerRegisterFontsForURL(file as CFURL, .process, &error) else { return true }
        let code = error.map { CFErrorGetCode($0.takeRetainedValue()) }
        if code == CFIndex(CTFontManagerError.alreadyRegistered.rawValue) {
            return true
        }
        logger.error("font \(name, privacy: .public) did not register, code \(code ?? 0)")
        return false
    }
}
