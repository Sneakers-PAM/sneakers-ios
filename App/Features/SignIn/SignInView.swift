// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

/// The sign-in screen: password first, then a code when the account has a second factor. Nothing else in the app
/// is reachable until it succeeds.
struct SignInView: View {
    let model: SignInModel

    @State private var username = ""
    @State private var password = ""
    @State private var showsPassword = false
    @State private var code = ""
    @State private var showsServers = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                switch model.step {
                case .credentials:
                    credentialsForm
                case let .secondFactor(_, selected):
                    codeForm(selected: selected)
                }
                if let message = model.message {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("signInMessage")
                }
                serverLine
            }
            .padding(24)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color("LaunchBackground").ignoresSafeArea())
        .sheet(isPresented: $showsServers) {
            ServersSheet()
        }
    }

    // MARK: Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            SneakerLoaderView(size: 72)
                .padding(.bottom, 4)
            Text(titleText)
                .lacesFont(.title)
                .tracking(-0.6)
                .accessibilityAddTraits(.isHeader)
            Text(subtitleText)
                .lacesFont(.bodyLarge)
                .foregroundStyle(.secondary)
        }
    }

    private var titleText: String {
        if case .secondFactor = model.step {
            "Enter your code"
        } else {
            "Sign in to continue"
        }
    }

    private var subtitleText: String {
        guard case let .secondFactor(_, selected) = model.step else {
            return "Use the account you have on this server."
        }
        return selected == .email
            ? "We emailed a 6-digit code to the address on your account."
            : "Open your authenticator app and enter the 6-digit code for this account."
    }

    private var credentialsForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Username", text: $username)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .fieldStyle()
                .accessibilityIdentifier("signInUsername")
            HStack {
                Group {
                    if showsPassword {
                        TextField("Password", text: $password)
                    } else {
                        SecureField("Password", text: $password)
                    }
                }
                .textContentType(.password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .onSubmit(signIn)
                .accessibilityIdentifier("signInPassword")
                Button(showsPassword ? "Hide" : "Show") { showsPassword.toggle() }
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("showPassword")
            }
            .fieldStyle()
            primaryButton("Sign in", id: "signInButton", disabled: username.isEmpty || password.isEmpty, action: signIn)
        }
    }

    private func codeForm(selected: SecondFactorKind) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if model.availableFactors.count > 1 {
                Picker("Method", selection: factorBinding(selected: selected)) {
                    ForEach(model.availableFactors, id: \.self) { kind in
                        Text(kind == .email ? "Email" : "Authenticator").tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("factorPicker")
            }
            CodeEntryView(code: $code)
            primaryButton("Verify and sign in", id: "verifyButton", disabled: code.count != 6, action: verify)
            HStack {
                Button("Use a different account") {
                    code = ""
                    model.back()
                }
                Spacer()
                if selected == .email {
                    Button("Send a new code") {
                        Task { await model.resendEmailCode() }
                    }
                }
            }
            .font(.subheadline)
        }
    }

    private var serverLine: some View {
        HStack {
            Text("Server")
                .foregroundStyle(.secondary)
            Text(model.server.name)
            Spacer()
            Button("Change") { showsServers = true }
                .accessibilityIdentifier("changeServer")
        }
        .font(.footnote)
    }

    private func primaryButton(_ title: String, id: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                if model.isWorking {
                    ProgressView()
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color("LacesInk"))
        .disabled(disabled || model.isWorking)
        .accessibilityIdentifier(id)
    }

    private func factorBinding(selected: SecondFactorKind) -> Binding<SecondFactorKind> {
        Binding(
            get: { selected },
            set: { kind in
                code = ""
                Task { await model.choose(kind) }
            }
        )
    }

    // MARK: Actions

    private func signIn() {
        guard !username.isEmpty, !password.isEmpty else { return }
        Task {
            await model.submit(username: username, password: password)
            if case .secondFactor = model.step {
                password = ""
            }
        }
    }

    private func verify() {
        Task {
            await model.submitCode(code)
            if case .secondFactor = model.step {
                code = ""
            }
        }
    }
}

private extension View {
    func fieldStyle() -> some View {
        padding(14)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }
}
