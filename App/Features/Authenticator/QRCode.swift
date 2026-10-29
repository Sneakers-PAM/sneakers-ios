// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import CoreImage.CIFilterBuiltins
import UIKit

/// Draws text as a QR code, sharp at any size. The text can be a secret, so nothing here logs or stores it.
nonisolated enum QRCode {
    static func image(for text: String, side: CGFloat) -> UIImage? {
        guard !text.isEmpty else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }

        let scale = max(1, (side / output.extent.width).rounded(.up))
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
