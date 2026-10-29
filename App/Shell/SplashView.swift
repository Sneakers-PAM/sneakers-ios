// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

/// The opening screen: the name, the slogan and the licence line are there from the start while the sneaker fills in.
struct SplashView: View {
    var body: some View {
        ZStack {
            Color("LaunchBackground").ignoresSafeArea()

            VStack(spacing: 24) {
                SneakerLoaderView(size: 160)
                VStack(spacing: 14) {
                    wordmark
                    slogan
                }
            }

            VStack {
                Spacer()
                footer
            }
            .padding(.bottom, 28)
        }
    }

    private var wordmark: some View {
        let dot = Text(SplashContent.wordmark.dot).foregroundColor(Color("LacesSole"))
        return Text("\(SplashContent.wordmark.start)\(dot)\(SplashContent.wordmark.end)")
            .lacesFont(.wordmark)
            .tracking(-0.6)
            .foregroundStyle(Color("LacesInk"))
    }

    private var slogan: some View {
        let mark = Text(SplashContent.trademark).font(.system(size: 12, weight: .bold)).baselineOffset(10)
        return Text("\(SplashContent.sloganLines.joined(separator: "\n"))\(mark)")
            .lacesFont(.slogan)
            .multilineTextAlignment(.center)
            .foregroundStyle(Color("LacesInk"))
    }

    private var footer: some View {
        VStack(spacing: 4) {
            ForEach(SplashContent.footerLines, id: \.self) { line in
                Text(line)
            }
        }
        .lacesFont(.mono)
        .foregroundStyle(.secondary)
    }
}

#Preview {
    SplashView()
}
