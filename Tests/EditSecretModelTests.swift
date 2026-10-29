// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Sneakers_PAM
import Testing

@MainActor
struct EditSecretModelTests {
    private let vault = FakeVaultService()

    private func makeAccess() -> VaultAccess {
        VaultAccess(service: vault, context: { .fixture }, onSessionEnded: {})
    }

    private func field(
        _ key: String,
        kind: String = "text",
        sensitive: Bool = false,
        required: Bool = false,
        maxLength: Int? = nil,
        options: [String]? = nil
    ) -> FieldDefinition {
        FieldDefinition(
            key: key, label: key.capitalized, kind: kind, sensitive: sensitive, superSensitive: false,
            options: options, required: required, maxLength: maxLength
        )
    }

    private func model(fields: [FieldDefinition]? = nil, values: [String: String] = [:]) -> EditSecretModel {
        let defaults = [field("username", required: true), field("password", kind: "password", sensitive: true)]
        return EditSecretModel(
            secretID: "s1", name: "DB admin", fields: fields ?? defaults,
            values: values.isEmpty ? ["username": "app_admin"] : values
        )
    }

    @Test func untouchedThereIsNothingToSave() {
        let edit = model()

        #expect(edit.change == nil)
        #expect(!edit.canSave)
    }

    @Test func plainFieldsStartWithTheirValueAndSensitiveOnesStartEmpty() {
        let edit = model()

        #expect(edit.value(for: "username") == "app_admin")
        #expect(edit.value(for: "password") == "")
    }

    @Test func aNewNameIsPartOfTheChange() {
        let edit = model()
        edit.name = "DB root"

        #expect(edit.change == SecretChange(name: "DB root", fields: [:]))
    }

    @Test func onlyTheFieldsThatChangedAreSent() {
        let edit = model()
        edit.set("bob", for: "username")

        #expect(edit.change == SecretChange(name: nil, fields: ["username": "bob"]))
    }

    @Test func aSensitiveFieldIsSentOnlyWhenSomethingIsTyped() {
        let edit = model()
        #expect(edit.change?.fields["password"] == nil)

        edit.set("n3w-secret", for: "password")
        #expect(edit.change?.fields["password"] == "n3w-secret")
    }

    @Test func aRequiredFieldCannotBeEmptied() {
        let edit = model()
        edit.set("", for: "username")

        #expect(edit.error(for: "username") != nil)
        #expect(!edit.canSave)
    }

    @Test func aNameCannotBeEmpty() {
        let edit = model()
        edit.name = "   "

        #expect(!edit.canSave)
    }

    @Test func aValueLongerThanTheLimitIsRefused() {
        let edit = model(fields: [field("code", maxLength: 4)], values: ["code": "abcd"])
        edit.set("abcde", for: "code")

        #expect(edit.error(for: "code") != nil)
        #expect(!edit.canSave)
    }

    @Test func aChoiceMustBeOneOfTheOptions() {
        let edit = model(fields: [field("mode", kind: "select", options: ["a", "b"])], values: ["mode": "a"])
        edit.set("zzz", for: "mode")
        #expect(edit.error(for: "mode") != nil)

        edit.set("b", for: "mode")
        #expect(edit.error(for: "mode") == nil)
        #expect(edit.canSave)
    }

    @Test func aFileFieldIsNotEditable() {
        let edit = model(fields: [field("cert", kind: "file"), field("note")], values: ["note": "x"])

        #expect(edit.editableFields.map(\.key) == ["note"])
    }

    @Test func savingSendsTheChangeAndSaysItWorked() async {
        let edit = model()
        edit.set("bob", for: "username")

        await edit.save(makeAccess())

        #expect(vault.updates.count == 1)
        #expect(vault.updates.first?.secretID == "s1")
        #expect(vault.updates.first?.change == SecretChange(name: nil, fields: ["username": "bob"]))
        #expect(edit.didSave)
        #expect(edit.message == nil)
    }

    @Test func aRefusedSaveSaysWhyAndKeepsTheDraft() async {
        vault.updateResult = .failure(.noAccess)
        let edit = model()
        edit.set("bob", for: "username")

        await edit.save(makeAccess())

        #expect(!edit.didSave)
        #expect(edit.message == VaultError.noAccess.message)
        #expect(edit.value(for: "username") == "bob")
    }

    @Test func savingWithNothingChangedDoesNotAskTheServer() async {
        let edit = model()

        await edit.save(makeAccess())

        #expect(vault.updates.isEmpty)
        #expect(!edit.didSave)
    }

    @Test func theTypedSecretIsForgottenOnceSaved() async {
        let edit = model()
        edit.set("n3w-secret", for: "password")

        await edit.save(makeAccess())

        #expect(edit.value(for: "password") == "")
    }
}
