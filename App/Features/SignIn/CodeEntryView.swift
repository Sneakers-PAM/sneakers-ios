// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

/// Six boxes for a one-time code. One hidden number field takes the input, so the keyboard's one-time-code
/// suggestion and pasting both work.
struct CodeEntryView: View {
    @Binding var code: String
    var length = 6

    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            TextField("6-digit code", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isFocused)
                .opacity(0.02)
                .accessibilityIdentifier("codeField")
            HStack(spacing: 10) {
                ForEach(0 ..< length, id: \.self) { index in
                    box(at: index)
                }
            }
            .accessibilityHidden(true)
            .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
        .onChange(of: code) { _, newValue in
            let digits = newValue.filter { $0.isASCII && $0.isNumber }
            let limited = String(digits.prefix(length))
            if limited != newValue {
                code = limited
            }
        }
        .task { isFocused = true }
    }

    private func box(at index: Int) -> some View {
        let characters = Array(code)
        let isCurrent = index == min(characters.count, length - 1) && isFocused
        return Text(index < characters.count ? String(characters[index]) : "")
            .font(.custom(BrandFonts.monoBold, size: 26, relativeTo: .title))
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isCurrent ? Color("LacesSole") : Color.secondary.opacity(0.25),
                        lineWidth: isCurrent ? 2 : 1
                    )
            }
    }
}

#Preview {
    @Previewable @State var code = "481"
    CodeEntryView(code: $code)
        .padding()
}
