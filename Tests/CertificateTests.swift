// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Sneakers_PAM
import Testing

@MainActor
struct CertificateTests {
    private let vault = FakeVaultService()
    private let transport = FakeGraphQLTransport()
    private let now = Date(timeIntervalSince1970: 1_793_000_000)

    private func makeAccess() -> VaultAccess {
        VaultAccess(service: vault, context: { .fixture }, onSessionEnded: {})
    }

    private func info(_ values: [String: String]) -> CertificateInfo {
        CertificateInfo(values: values)
    }

    @Test func onlyTheCertificateTypeIsACertificate() {
        #expect(CertificateInfo.isCertificate(typeID: "type-ssl-cert"))
        #expect(!CertificateInfo.isCertificate(typeID: "t1"))
        #expect(!CertificateInfo.isCertificate(typeID: nil))
    }

    @Test func aCertificateReadsItsDetailsFromItsPlainFields() {
        var values: [String: String] = ["subject": "CN=edge.example.org", "issuer": "CN=Example CA"]
        values["keyAlgorithm"] = "RSA"
        values["keyBits"] = "2048"
        values["fingerprintSha256"] = "AB:CD"
        values["hasPrivateKey"] = "true"
        values["notAfter"] = "2026-12-01T00:00:00Z"
        let item = info(values)

        #expect(item.subject == "CN=edge.example.org")
        #expect(item.issuer == "CN=Example CA")
        #expect(item.keyLabel == "RSA 2048")
        #expect(item.fingerprint == "AB:CD")
        #expect(item.hasPrivateKey)
    }

    @Test func anEllipticKeyIsNamedWithItsCurve() {
        #expect(info(["keyAlgorithm": "EC", "keyBits": "256"]).keyLabel == "EC P-256")
        #expect(info([:]).keyLabel == "Unknown")
        #expect(info(["keyAlgorithm": "Ed25519"]).keyLabel == "Ed25519")
    }

    @Test func expiryIsValidThenExpiringInTheLastThirtyDaysThenExpired() {
        func label(_ days: Int) -> String {
            let when = now.addingTimeInterval(TimeInterval(days) * 86400 + 3600)
            return info(["notAfter": ISO8601DateFormatter().string(from: when)]).expiry(now: now).label
        }
        #expect(label(120) == "Valid, 120 days")
        #expect(label(12) == "Expiring, 12 days")
        #expect(label(30) == "Expiring, 30 days")
        #expect(label(-3) == "Expired")
        #expect(info([:]).expiry(now: now).label == "Unknown")
    }

    @Test func theExportFormatsAreTheWebs() {
        let values = CertificateExportFormat.all.map(\.value)

        #expect(values == ["pem-fullchain", "pem", "pkcs12", "der", "jks"])
        #expect(CertificateExportFormat.all[0].passphrase == .notAsked)
        #expect(CertificateExportFormat.all[1].passphrase == .optional)
        #expect(CertificateExportFormat.all[2].passphrase == .required)
        #expect(CertificateExportFormat.all[2].needsKey)
        #expect(!CertificateExportFormat.all[3].needsKey)
    }

    @Test func aFormatThatNeedsAPassphraseCannotBeExportedWithoutOne() {
        let model = CertificateExportModel(secretID: "s5", hasPrivateKey: true)
        model.format = CertificateExportFormat.all[2]

        #expect(!model.canExport)
        model.passphrase = "hunter2"
        #expect(model.canExport)
    }

    @Test func aFormatWithTheKeyIsNotOfferedWhenThereIsNoKeyOnFile() {
        let model = CertificateExportModel(secretID: "s5", hasPrivateKey: false)

        #expect(model.formats.map(\.value) == ["pem-fullchain", "der"])
    }

    @Test func exportingSendsTheFormatAndPassphraseAndHoldsTheFile() async {
        let file = CertificateFile(data: Data("cert".utf8), filename: "edge.p12", contentType: "application/x-pkcs12")
        vault.exportResult = .success(file)
        let model = CertificateExportModel(secretID: "s5", hasPrivateKey: true)
        model.format = CertificateExportFormat.all[2]
        model.passphrase = "hunter2"

        await model.export(makeAccess())

        #expect(vault.exports.first?.secretID == "s5")
        #expect(vault.exports.first?.format == "pkcs12")
        #expect(vault.exports.first?.passphrase == "hunter2")
        #expect(model.file == file)
        #expect(model.passphrase == "")
    }

    @Test func aFormatThatAsksNoPassphraseSendsNone() async {
        vault.exportResult = .success(CertificateFile(data: Data(), filename: "a.pem", contentType: "x"))
        let model = CertificateExportModel(secretID: "s5", hasPrivateKey: true)
        model.passphrase = "left over"

        await model.export(makeAccess())

        #expect(vault.exports.first?.passphrase == nil)
    }

    @Test func aRefusedExportSaysWhyAndKeepsNothing() async {
        vault.exportResult = .failure(.noAccess)
        let model = CertificateExportModel(secretID: "s5", hasPrivateKey: true)

        await model.export(makeAccess())

        #expect(model.file == nil)
        #expect(model.message == VaultError.noAccess.message)
    }

    @Test func theServiceDecodesTheFileAndSendsTheFormat() async throws {
        let encoded = Data("PEM".utf8).base64EncodedString()
        transport.answer("SecretExportCertificate", """
        {"exportCertificate":{"fileBase64":"\(encoded)","filename":"edge.pem","contentType":"application/x-pem-file"}}
        """)

        let file = try await HTTPVaultService(transport: transport)
            .exportCertificate(CertificateExportRequest(secretID: "s5", format: "pem", passphrase: "pw"), .fixture)

        #expect(file.data == Data("PEM".utf8))
        #expect(file.filename == "edge.pem")
        let variables = transport.operation(named: "SecretExportCertificate")?.variables
        #expect(variables?["secretId"] == .string("s5"))
        #expect(variables?["format"] == .string("pem"))
        #expect(variables?["newPassphrase"] == .string("pw"))
    }

    @Test func aNoPassphraseExportSendsNoPassphrase() async throws {
        transport.answer("SecretExportCertificate", """
        {"exportCertificate":{"fileBase64":"","filename":"a.der","contentType":"x"}}
        """)

        _ = try await HTTPVaultService(transport: transport)
            .exportCertificate(CertificateExportRequest(secretID: "s5", format: "der", passphrase: nil), .fixture)

        #expect(transport.operation(named: "SecretExportCertificate")?.variables["newPassphrase"] == nil)
    }

    @Test func aFileThatIsNotBase64IsUnexpected() async {
        transport.answer("SecretExportCertificate", """
        {"exportCertificate":{"fileBase64":"@@@","filename":"a.der","contentType":"x"}}
        """)

        await #expect(throws: VaultError.unexpected) {
            try await HTTPVaultService(transport: transport)
                .exportCertificate(CertificateExportRequest(secretID: "s5", format: "der", passphrase: nil), .fixture)
        }
    }
}
