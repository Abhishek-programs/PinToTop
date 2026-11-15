
import CoreGraphics

@MainActor
final class ScreenRecordingAccess {
    private(set) var isGranted = CGPreflightScreenCaptureAccess()
    private(set) var didRequestThisLaunch = false

    func preflight() -> Bool {
        isGranted = CGPreflightScreenCaptureAccess()
        return isGranted
    }

    var statusWhileDenied: String {
        didRequestThisLaunch
        ? "Screen Recording access was not granted."
        : "Requesting Screen Recording access…"
        }

    func requestIfNeeded() -> Bool {
        guard !preflight(), !didRequestThisLaunch else {
            return isGranted
        }

        didRequestThisLaunch = true
        isGranted = CGRequestScreenCaptureAccess() || CGPreflightScreenCaptureAccess()

        return isGranted
    }
}
