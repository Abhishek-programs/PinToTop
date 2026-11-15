import AppKit
import CoreImage
import ScreenCaptureKit

final class FrameOutput: NSObject, SCStreamOutput {
    private let onFrame: (NSImage) -> Void
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    init(onFrame: @escaping (NSImage) -> Void) { self.onFrame = onFrame }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              CMSampleBufferIsValid(sampleBuffer),
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }
        onFrame(NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height)))
    }
}
