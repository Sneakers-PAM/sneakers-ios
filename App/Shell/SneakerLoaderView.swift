// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

/// The Laces sneaker loader: the sole fills left to right, ink rises through the body, then the keyhole
/// and laces appear. It shows no wordmark or text. With Reduce Motion on it renders filled at once.
struct SneakerLoaderView: View {
    var size: CGFloat = 160

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startDate = Date.now
    @State private var isFinished = false

    var body: some View {
        TimelineView(.animation(paused: isFinished || reduceMotion)) { context in
            let elapsed = reduceMotion ? SneakerLoaderProgress.total : context.date.timeIntervalSince(startDate)
            Canvas { graphics, canvasSize in
                SneakerMark.draw(
                    in: &graphics,
                    size: canvasSize,
                    state: SneakerLoaderProgress(progress: SneakerLoaderProgress.progress(elapsed: elapsed)),
                    time: elapsed
                )
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isFinished ? "Sneakers-PAM" : "Loading Sneakers-PAM")
        .task {
            guard !reduceMotion else {
                isFinished = true
                return
            }
            try? await Task.sleep(for: .seconds(SneakerLoaderProgress.total))
            isFinished = true
        }
    }
}

/// Draws the mark in its 64 by 64 design space, scaled to the canvas.
private enum SneakerMark {
    private static let bodyOutline: Path = {
        var path = Path()
        path.move(to: CGPoint(x: 6, y: 43))
        path.addCurve(to: CGPoint(x: 19, y: 16), control1: CGPoint(x: 6, y: 30), control2: CGPoint(x: 10, y: 18))
        path.addLine(to: CGPoint(x: 27, y: 16))
        path.addCurve(to: CGPoint(x: 45, y: 30), control1: CGPoint(x: 29, y: 24), control2: CGPoint(x: 36, y: 29))
        path.addLine(to: CGPoint(x: 53, y: 32))
        path.addCurve(to: CGPoint(x: 60, y: 41), control1: CGPoint(x: 58, y: 33), control2: CGPoint(x: 60, y: 37))
        path.addLine(to: CGPoint(x: 60, y: 43))
        path.addLine(to: CGPoint(x: 6, y: 43))
        path.closeSubpath()
        return path
    }()

    private static let topLace = (from: CGPoint(x: 30, y: 23), to: CGPoint(x: 35, y: 21))
    private static let middleLace = (from: CGPoint(x: 34, y: 27), to: CGPoint(x: 39, y: 25))
    private static let bottomLace = (from: CGPoint(x: 39, y: 30), to: CGPoint(x: 44, y: 28))
    private static let laces = [topLace, middleLace, bottomLace]

    static func draw(in graphics: inout GraphicsContext, size: CGSize, state: SneakerLoaderProgress, time: Double) {
        let ink = Color("LacesInk")
        let sole = Color("LacesSole")
        let hole = Color("LaunchBackground")

        let scale = min(size.width, size.height) / 64
        graphics.scaleBy(x: scale, y: scale)

        graphics.drawLayer { layer in
            layer.opacity = 1 - state.body * 0.9
            layer.stroke(bodyOutline, with: .color(ink), style: StrokeStyle(lineWidth: 2.2, lineJoin: .round))
        }

        graphics.drawLayer { layer in
            layer.clip(to: bodyOutline)
            layer.fill(wave(level: state.inkLevel, body: state.body, time: time), with: .color(ink))
        }

        let soleBar = CGRect(x: 4, y: 44, width: 58, height: 10)
        graphics.drawLayer { layer in
            layer.opacity = 1 - state.sole
            layer.stroke(Path(roundedRect: soleBar, cornerRadius: 5), with: .color(sole), lineWidth: 1.6)
        }
        let filled = CGRect(x: 4, y: 44, width: max(0.01, 58 * state.sole), height: 10)
        graphics.fill(Path(roundedRect: filled, cornerRadius: 5), with: .color(sole))

        graphics.drawLayer { layer in
            layer.opacity = state.hole
            let pivot = CGPoint(x: 19, y: 32)
            let holeScale = 0.6 + 0.4 * state.hole
            layer.translateBy(x: pivot.x, y: pivot.y)
            layer.scaleBy(x: holeScale, y: holeScale)
            layer.translateBy(x: -pivot.x, y: -pivot.y)
            layer.fill(Path(ellipseIn: CGRect(x: 14.8, y: 24.8, width: 8.4, height: 8.4)), with: .color(hole))
            let keyhole = CGRect(x: 17.4, y: 30, width: 3.2, height: 8)
            layer.fill(Path(roundedRect: keyhole, cornerRadius: 1.2), with: .color(hole))
        }

        for (index, lace) in laces.enumerated() {
            let drawn = state.laceProgress(at: index)
            guard drawn > 0 else { continue }
            var line = Path()
            line.move(to: lace.from)
            line.addLine(to: CGPoint(
                x: lace.from.x + (lace.to.x - lace.from.x) * drawn,
                y: lace.from.y + (lace.to.y - lace.from.y) * drawn
            ))
            graphics.stroke(line, with: .color(hole), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
        }
    }

    /// The ink: a sine surface that moves sideways and flattens as the body fills.
    private static func wave(level: Double, body: Double, time: Double) -> Path {
        let amplitude = body > 0 ? 2.4 * (1 - body) : 0
        let phase = (time * 28).truncatingRemainder(dividingBy: 16)
        var cursor = -32 + phase
        let startX = cursor
        var path = Path()
        path.move(to: CGPoint(x: cursor, y: level))
        while cursor < 80 {
            path.addQuadCurve(
                to: CGPoint(x: cursor + 8, y: level),
                control: CGPoint(x: cursor + 4, y: level - amplitude)
            )
            path.addQuadCurve(
                to: CGPoint(x: cursor + 16, y: level),
                control: CGPoint(x: cursor + 12, y: level + amplitude)
            )
            cursor += 16
        }
        path.addLine(to: CGPoint(x: cursor, y: 64))
        path.addLine(to: CGPoint(x: startX, y: 64))
        path.closeSubpath()
        return path
    }
}

#Preview {
    ZStack {
        Color("LaunchBackground").ignoresSafeArea()
        SneakerLoaderView()
    }
}
