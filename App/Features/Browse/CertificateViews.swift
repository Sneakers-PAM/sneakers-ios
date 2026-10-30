// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import SwiftUI
import UniformTypeIdentifiers

/// A certificate saved to a file the person picks. The bytes exist only here, until the file is written.
nonisolated struct CertificateDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.data]

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

/// A certificate secret at a glance: how long it has left, who it is for and from, its key, and a way to export it.
struct CertificateCard: View {
    let info: CertificateInfo
    let secretID: String
    let canExport: Bool

    @State private var exporting: CertificateExportModel?

    private var expiry: CertificateExpiry {
        info.expiry()
    }

    private var color: Color {
        switch expiry.tone {
        case .valid: .green
        case .warning: .orange
        case .danger: .red
        case .unknown: .gray
        }
    }

    var body: some View {
        Section("Certificate") {
            Label {
                Text(expiry.label)
            } icon: {
                Image(systemName: "circle.fill").foregroundStyle(color).imageScale(.small)
            }
            .accessibilityIdentifier("certExpiry")
            if let subject = info.subject {
                LabeledContent("For", value: subject)
            }
            if let issuer = info.issuer {
                LabeledContent("Issued by", value: issuer)
            }
            LabeledContent("Key", value: info.keyLabel)
            if let fingerprint = info.fingerprint {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SHA-256 fingerprint").font(.footnote).foregroundStyle(.secondary)
                    Text(fingerprint)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
            if canExport {
                Button("Export", systemImage: "square.and.arrow.up") {
                    exporting = CertificateExportModel(secretID: secretID, hasPrivateKey: info.hasPrivateKey)
                }
                .accessibilityIdentifier("certExport")
                .sheet(item: $exporting) { model in
                    CertificateExportView(model: model)
                }
            }
        }
    }
}

extension CertificateExportModel: Identifiable {
    nonisolated var id: String {
        secretID
    }
}

/// Picks a format, asks for a passphrase where the vault wants one, and hands the file to the system's save panel.
struct CertificateExportView: View {
    @Bindable var model: CertificateExportModel

    @Environment(VaultAccess.self) private var access
    @Environment(\.dismiss) private var dismiss
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Format") {
                    Picker("Format", selection: $model.format) {
                        ForEach(model.formats) { format in
                            Text(format.label).tag(format)
                        }
                    }
                    .accessibilityIdentifier("certFormat")
                    Text(model.format.hint).font(.footnote).foregroundStyle(.secondary)
                }
                if model.format.passphrase != .notAsked {
                    Section {
                        SecureField("New passphrase", text: $model.passphrase)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .accessibilityIdentifier("certPassphrase")
                    } footer: {
                        Text(model.format
                            .passphrase == .required ? "Needed to protect the key in this file." : "Optional.")
                    }
                }
                if let message = model.message {
                    Section { Text(message).foregroundStyle(.red).accessibilityIdentifier("certMessage") }
                }
            }
            .navigationTitle("Export certificate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Export") { Task { await export() } }
                        .disabled(!model.canExport)
                        .accessibilityIdentifier("certExportConfirm")
                }
            }
            .fileExporter(
                isPresented: $isSaving,
                document: CertificateDocument(data: model.file?.data ?? Data()),
                contentType: .data,
                defaultFilename: model.file?.filename ?? "certificate"
            ) { _ in
                model.clearFile()
                dismiss()
            }
        }
    }

    private func export() async {
        await model.export(access)
        isSaving = model.file != nil
    }
}
