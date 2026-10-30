// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// How close a certificate is to its end.
nonisolated struct CertificateExpiry: Equatable, Sendable {
    enum Tone: Equatable, Sendable {
        case valid, warning, danger, unknown
    }

    let days: Int?
    let label: String
    let tone: Tone
}

/// A certificate secret's details, read from the plain fields the vault keeps for it. None of it is secret, and the key
/// material is never part of it.
nonisolated struct CertificateInfo: Equatable, Sendable {
    /// The type id of a certificate secret.
    static let typeID = "type-ssl-cert"
    /// A certificate this close to its end reads as expiring.
    static let expiringDays = 30

    let values: [String: String]

    static func isCertificate(typeID id: String?) -> Bool {
        id == typeID
    }

    var subject: String? {
        values["subject"]
    }

    var issuer: String? {
        values["issuer"]
    }

    var fingerprint: String? {
        values["fingerprintSha256"]
    }

    var hasPrivateKey: Bool {
        values["hasPrivateKey"] == "true"
    }

    var keyLabel: String {
        guard let algorithm = values["keyAlgorithm"], !algorithm.isEmpty else { return "Unknown" }
        let bits = values["keyBits"] ?? ""
        if algorithm.uppercased().hasPrefix("EC") {
            return bits.isEmpty ? algorithm : "\(algorithm) P-\(bits)"
        }
        return bits.isEmpty ? algorithm : "\(algorithm) \(bits)"
    }

    var notAfter: Date? {
        values["notAfter"].flatMap(GatewayDate.parse)
    }

    func expiry(now: Date = .now) -> CertificateExpiry {
        guard let end = notAfter else { return CertificateExpiry(days: nil, label: "Unknown", tone: .unknown) }
        let days = Int((end.timeIntervalSince(now) / 86400).rounded(.down))
        if end < now {
            return CertificateExpiry(days: days, label: "Expired", tone: .danger)
        }
        if days <= Self.expiringDays {
            return CertificateExpiry(
                days: days,
                label: "Expiring, \(days) days",
                tone: .warning
            )
        }
        return CertificateExpiry(days: days, label: "Valid, \(days) days", tone: .valid)
    }
}

/// Whether the vault wants a new passphrase to protect the exported key.
nonisolated enum PassphraseRule: Equatable, Sendable {
    case notAsked, optional, required
}

/// A way to export a certificate, as the web offers them.
nonisolated struct CertificateExportFormat: Equatable, Hashable, Identifiable, Sendable {
    let value: String
    let label: String
    let hint: String
    /// Carries the private key, so it needs one on file.
    let needsKey: Bool
    let passphrase: PassphraseRule

    var id: String {
        value
    }

    static let all: [CertificateExportFormat] = {
        var formats: [CertificateExportFormat] = []
        formats.append(CertificateExportFormat(
            value: "pem-fullchain", label: "PEM, certificate and chain", hint: "No private key. Safe to share.",
            needsKey: false, passphrase: .notAsked
        ))
        formats.append(CertificateExportFormat(
            value: "pem", label: "PEM with private key", hint: "Key re-encrypted with a passphrase.",
            needsKey: true, passphrase: .optional
        ))
        formats.append(CertificateExportFormat(
            value: "pkcs12", label: "PKCS#12 / PFX", hint: "Certificate, chain and key in one file.",
            needsKey: true, passphrase: .required
        ))
        formats.append(CertificateExportFormat(
            value: "der", label: "DER", hint: "Certificate only, binary.", needsKey: false, passphrase: .notAsked
        ))
        formats.append(CertificateExportFormat(
            value: "jks", label: "Java keystore (JKS)", hint: "Certificate and key, passphrase protected.",
            needsKey: true, passphrase: .required
        ))
        return formats
    }()
}

/// An exported certificate, ready to be saved to a file the person chooses.
nonisolated struct CertificateFile: Equatable, Sendable {
    let data: Data
    let filename: String
    let contentType: String
}

/// What to export and how.
nonisolated struct CertificateExportRequest: Equatable, Sendable {
    let secretID: String
    let format: String
    let passphrase: String?
}
