import UIKit
import CoreImage.CIFilterBuiltins

/// Generates a crisp black-and-white QR code `UIImage` from a string payload.
/// Uses the built-in CoreImage generator; safe to call on the main thread for
/// small strings (< 300 bytes).
enum QRCodeGenerator {
    static func image(from string: String) -> UIImage? {
        guard let data = string.data(using: .utf8) else { return nil }

        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = "M"

        guard let ciImage = filter.outputImage else { return nil }

        // Scale up so the image is sharp when rendered in SwiftUI.
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: 12, y: 12))

        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
