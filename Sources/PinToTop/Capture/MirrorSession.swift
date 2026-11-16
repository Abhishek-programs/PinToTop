import AppKit
import ScreenCaptureKit

@MainActor
final class MirrorSession {
    private var stream: SCStream?
    private var output: FrameOutput?
    private var delegate: StreamStopDelegate?
    private var configuration: SCStreamConfiguration?
    private var pixelScale: CGFloat = 2
    private var capturedPointSize: CGSize = .zero

    /// Starts capturing one window.
    /// - onFrame: a new, fully rendered frame arrived.
    /// - onPaused: the source stopped producing visible frames (e.g. minimized).
    /// - onStop: ScreenCaptureKit stopped the stream on its own (error, window gone).
    func start(
        window: WindowChoice,
        onFrame: @escaping (NSImage) -> Void,
        onPaused: @escaping () -> Void,
        onStop: @escaping (Error) -> Void
    ) async throws {
        await stop()
        let filter = SCContentFilter(desktopIndependentWindow: window.window)
        pixelScale = CGFloat(filter.pointPixelScale)
        let pointSize = filter.contentRect.size == .zero ? window.size : filter.contentRect.size

        let config = SCStreamConfiguration()
        apply(pointSize: pointSize, to: config)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        config.queueDepth = 3
        config.showsCursor = false
        config.capturesAudio = false
        config.scalesToFit = true
        config.preservesAspectRatio = true

        let frameOutput = FrameOutput(
            onFrame: { frame in Task { @MainActor in onFrame(frame) } },
            onPaused: { Task { @MainActor in onPaused() } }
        )
        let stopDelegate = StreamStopDelegate { error in Task { @MainActor in onStop(error) } }
        let captureStream = SCStream(filter: filter, configuration: config, delegate: stopDelegate)
        try captureStream.addStreamOutput(
            frameOutput,
            type: .screen,
            sampleHandlerQueue: DispatchQueue(label: "pintotop.frames")
        )
        try await captureStream.startCapture()
        output = frameOutput
        delegate = stopDelegate
        configuration = config
        capturedPointSize = pointSize
        stream = captureStream
    }

    /// Re-sizes the capture buffer when the source window changes size,
    /// so the mirror stays sharp instead of scaling a stale resolution.
    func resize(to pointSize: CGSize) async {
        guard let stream, let configuration,
              pointSize.width >= 1, pointSize.height >= 1,
              abs(pointSize.width - capturedPointSize.width) >= 1
                || abs(pointSize.height - capturedPointSize.height) >= 1 else { return }
        apply(pointSize: pointSize, to: configuration)
        do {
            try await stream.updateConfiguration(configuration)
            capturedPointSize = pointSize
        } catch {
            // Keep the previous size; the next check will retry.
        }
    }

    func stop() async {
        if let stream {
            do { try await stream.stopCapture() } catch { }
        }
        stream = nil
        output = nil
        delegate = nil
        configuration = nil
        capturedPointSize = .zero
    }

    private func apply(pointSize: CGSize, to config: SCStreamConfiguration) {
        config.width = max(2, Int((pointSize.width * pixelScale).rounded()))
        config.height = max(2, Int((pointSize.height * pixelScale).rounded()))
    }
}

private final class StreamStopDelegate: NSObject, SCStreamDelegate {
    private let onStop: (Error) -> Void

    init(onStop: @escaping (Error) -> Void) { self.onStop = onStop }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        onStop(error)
    }
}
