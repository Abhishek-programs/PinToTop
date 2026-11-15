import AppKit
import ScreenCaptureKit

@MainActor
final class MirrorSession {
    private var stream: SCStream?
    private var output: FrameOutput?

    func start(window: WindowChoice, onFrame: @escaping (NSImage) -> Void) async throws {
        await stop()
        let filter = SCContentFilter(desktopIndependentWindow: window.window)
        let config = SCStreamConfiguration()
        config.width = max(2, Int(window.size.width * 2))
        config.height = max(2, Int(window.size.height * 2))
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        config.queueDepth = 3
        config.showsCursor = false
        config.capturesAudio = false

        let frameOutput = FrameOutput { frame in
            Task { @MainActor in onFrame(frame) }
        }
        let captureStream = SCStream(filter: filter, configuration: config, delegate: nil)
        try captureStream.addStreamOutput(
            frameOutput,
            type: .screen,
            sampleHandlerQueue: DispatchQueue(label: "floaty.frames")
        )
        try await captureStream.startCapture()
        output = frameOutput
        stream = captureStream
    }

    func stop() async {
        if let stream {
            do { try await stream.stopCapture() } catch { }
        }
        stream = nil
        output = nil
    }
}
