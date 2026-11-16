import AppKit
import CoreImage
import ScreenCaptureKit

/// Runs on the stream's serial sample queue.
final class FrameOutput: NSObject, SCStreamOutput {
    private let onFrame: (NSImage) -> Void
    private let onPaused: () -> Void
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private var isPaused = false

    init(onFrame: @escaping (NSImage) -> Void, onPaused: @escaping () -> Void) {
        self.onFrame = onFrame
        self.onPaused = onPaused
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, CMSampleBufferIsValid(sampleBuffer) else { return }

        switch Self.status(of: sampleBuffer) {
        case .complete, nil:
            break
        case .blank, .suspended, .stopped:
            // Source is minimized, hidden, or otherwise not drawable.
            if !isPaused {
                isPaused = true
                onPaused()
            }
            return
        default:
            // .idle (nothing changed) and .started carry no new image.
            return
        }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }
        isPaused = false
        onFrame(NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height)))
    }

    private static func status(of sampleBuffer: CMSampleBuffer) -> SCFrameStatus? {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false)
                as? [[SCStreamFrameInfo: Any]],
              let raw = attachments.first?[.status] as? Int else { return nil }
        return SCFrameStatus(rawValue: raw)
    }
}
