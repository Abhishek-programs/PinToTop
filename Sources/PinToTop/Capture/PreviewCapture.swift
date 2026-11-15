import AppKit
import ScreenCaptureKit

@MainActor
final class PreviewCapturer {
    private let gate = PreviewCaptureGate()

    func capture(window: SCWindow) async -> NSImage? {
        guard CGPreflightScreenCaptureAccess() else { return nil }
        await gate.acquire()
        do {
            let config = SCStreamConfiguration()
            config.width = 480
            config.height = 270
            config.showsCursor = false
            config.capturesAudio = false
            let filter = SCContentFilter(desktopIndependentWindow: window)
            let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            await gate.release()
            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        } catch {
            await gate.release()
            return nil
        }
    }
}

private actor PreviewCaptureGate {
    private var activeCaptures = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        if activeCaptures < 2 {
            activeCaptures += 1
            return
        }
        await withCheckedContinuation { continuation in waiters.append(continuation) }
    }

    func release() {
        if waiters.isEmpty {
            activeCaptures = max(0, activeCaptures - 1)
        } else {
            waiters.removeFirst().resume()
        }
    }
}
