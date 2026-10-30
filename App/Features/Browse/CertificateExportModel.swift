// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Observation

/// Exporting a certificate: pick a format, give a passphrase where one is needed, and get the file. The file is held
/// only until it has been saved or the screen goes away, and the passphrase is forgotten at once.
@MainActor
@Observable
final class CertificateExportModel {
    let secretID: String
    let formats: [CertificateExportFormat]
    var format: CertificateExportFormat
    var passphrase = ""
    private(set) var file: CertificateFile?
    private(set) var isWorking = false
    private(set) var message: String?

    init(secretID: String, hasPrivateKey: Bool) {
        self.secretID = secretID
        let offered = CertificateExportFormat.all.filter { hasPrivateKey || !$0.needsKey }
        formats = offered
        format = offered[0]
    }

    var canExport: Bool {
        guard !isWorking else { return false }
        if format.passphrase == .required {
            return !passphrase.isEmpty
        }
        return true
    }

    func clearFile() {
        file = nil
    }

    func export(_ access: VaultAccess) async {
        guard canExport else { return }
        isWorking = true
        message = nil
        file = nil
        defer {
            isWorking = false
            passphrase = ""
        }
        let sent = format.passphrase == .notAsked || passphrase.isEmpty ? nil : passphrase
        let request = CertificateExportRequest(secretID: secretID, format: format.value, passphrase: sent)
        do {
            file = try await access.perform { try await access.service.exportCertificate(request, $0) }
        } catch {
            message = (error as? VaultError ?? .unexpected).message
        }
    }
}
