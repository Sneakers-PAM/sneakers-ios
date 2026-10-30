// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

#if DEBUG
    import Foundation

    /// A certificate secret in the made-up vault, with the plain fields the vault keeps for one.
    extension DemoVaultService {
        static let certificateType: SecretType = {
            func plain(_ key: String, _ label: String) -> FieldDefinition {
                FieldDefinition(key: key, label: label, kind: "text", sensitive: false, superSensitive: false)
            }
            let keys = "subject issuer keyAlgorithm keyBits fingerprintSha256 hasPrivateKey notAfter"
            var fields = keys.split(separator: " ").map { plain(String($0), String($0)) }
            fields.append(FieldDefinition(
                key: "privateKey", label: "Private key", kind: "multiline", sensitive: true, superSensitive: false
            ))
            return SecretType(id: CertificateInfo.typeID, name: "Certificate", checkout: false, fields: fields)
        }()

        var certificateSummary: SecretSummary {
            SecretSummary(
                id: "s5", name: "Edge certificate", folderId: "3", typeId: CertificateInfo.typeID, targetId: nil,
                lastHeartbeatResult: nil, retired: false, canRead: true, viewCount: 1, lastAccessedAt: nil
            )
        }

        func certificateDetail() -> SecretDetail {
            let end = ISO8601DateFormatter().string(from: Date().addingTimeInterval(86400 * 20))
            var values = ["subject": "CN=edge.example.org", "issuer": "CN=Example CA", "keyAlgorithm": "RSA"]
            values["keyBits"] = "2048"
            values["fingerprintSha256"] = "AB:CD:EF:01"
            values["hasPrivateKey"] = "true"
            values["notAfter"] = end
            return SecretDetail(
                summary: certificateSummary, type: Self.certificateType, values: values, lease: nil,
                folderPath: "Apps", expiresAt: nil, verifiedAt: nil, nextRotationAt: nil
            )
        }
    }
#endif
