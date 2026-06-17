import Vision
import CoreImage
import UIKit

actor SubjectExtractor {

    struct Result {
        let image: UIImage  // transparent-background PNG with white border
        let scale: Double   // fraction of canvas width (subject width / photo width)
    }

    enum ExtractionError: Error {
        case invalidImage, noSubject, renderFailed
    }

    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    func extract(from photo: UIImage) async throws -> Result {
        guard let cgImage = photo.cgImage else { throw ExtractionError.invalidImage }

        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage)
        try handler.perform([request])

        guard let obs = request.results?.first, !obs.allInstances.isEmpty else {
            throw ExtractionError.noSubject
        }

        // Pick the single most prominent instance
        let targetInstance = IndexSet([obs.allInstances.first!])
        let maskBuffer = try obs.generateScaledMaskForImage(forInstances: targetInstance, from: handler)

        let imageCI = CIImage(cgImage: cgImage)
        let maskCI = CIImage(cvPixelBuffer: maskBuffer)

        // Vision output is flipped relative to CIImage coordinate space
        let flip = CGAffineTransform(translationX: 0, y: maskCI.extent.height).scaledBy(x: 1, y: -1)
        let mask = maskCI.transformed(by: flip)

        // Dilate mask to create white border sticker effect
        let dilated = mask.applyingFilter("CIMorphologyMaximum", parameters: ["inputRadius": 6.0])

        let clear = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0))
            .cropped(to: imageCI.extent)

        // White border using dilated mask
        let border = CIImage(color: .white).cropped(to: imageCI.extent)
            .applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: clear,
                kCIInputMaskImageKey: dilated
            ])

        // Subject extracted with original mask
        let foreground = imageCI.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: clear,
            kCIInputMaskImageKey: mask
        ])

        // Foreground composited over white border
        let composite = foreground.composited(over: border)

        // Compute bounding box from mask buffer for scale and tight crop
        let bounds = subjectBounds(in: maskBuffer, imageSize: CGSize(width: cgImage.width, height: cgImage.height))

        // CIImage is bottom-origin; flip bounds Y to match
        let flippedBounds = CGRect(
            x: bounds.minX,
            y: CGFloat(cgImage.height) - bounds.maxY,
            width: bounds.width,
            height: bounds.height
        )
        let cropped = composite.cropped(to: flippedBounds)

        guard let cgOut = ciContext.createCGImage(cropped, from: cropped.extent) else {
            throw ExtractionError.renderFailed
        }

        let scale = min(Double(bounds.width) / Double(cgImage.width), 0.65)
        return Result(image: UIImage(cgImage: cgOut), scale: max(scale, 0.10))
    }

    // Scans mask buffer at 1/4 resolution to find the subject's tight bounding box
    private func subjectBounds(in buffer: CVPixelBuffer, imageSize: CGSize) -> CGRect {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }

        let w = CVPixelBufferGetWidth(buffer)
        let h = CVPixelBufferGetHeight(buffer)
        guard let base = CVPixelBufferGetBaseAddress(buffer) else {
            return CGRect(origin: .zero, size: imageSize)
        }
        let bpr = CVPixelBufferGetBytesPerRow(buffer)
        let pixels = base.assumingMemoryBound(to: UInt8.self)

        var minX = w, maxX = 0, minY = h, maxY = 0
        let step = 4  // sample every 4 pixels for speed
        for y in stride(from: 0, to: h, by: step) {
            for x in stride(from: 0, to: w, by: step) {
                if pixels[y * bpr + x] > 128 {
                    minX = min(minX, x); maxX = max(maxX, x)
                    minY = min(minY, y); maxY = max(maxY, y)
                }
            }
        }

        guard minX <= maxX else { return CGRect(origin: .zero, size: imageSize) }

        let sx = imageSize.width / CGFloat(w)
        let sy = imageSize.height / CGFloat(h)
        return CGRect(
            x: CGFloat(minX) * sx,
            y: CGFloat(minY) * sy,
            width: CGFloat(maxX - minX) * sx,
            height: CGFloat(maxY - minY) * sy
        )
    }
}
