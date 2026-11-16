import AppKit
import SwiftUI

@MainActor
final class MirrorModel: ObservableObject {
    @Published private(set) var windows: [WindowChoice] = []
    @Published private(set) var displays: [DisplayChoice] = []
    @Published private(set) var hasScreenCaptureAccess: Bool
    @Published var selectedDisplayID: CGDirectDisplayID?
    @Published var selectedID: CGWindowID?
    /// Live frames live in their own object so 30 fps updates only re-render
    /// the overlays, not every view observing the model (main window, menu).
    let frames = FrameStore()
    @Published var status = "Choose a window to pin."
    @Published var isMirroring = false
    @Published private(set) var sourceDescription: String?
    @Published private(set) var isSourcePaused = false

    /// Registered by the always-present menu bar label, which has SwiftUI's
    /// `openWindow` action. Lets non-view code open the main window.
    var openMainWindow: (() -> Void)?
    private var mirrorGeneration = 0
    private var watchTask: Task<Void, Never>?

    private let access = ScreenRecordingAccess()
    private let inventory = WindowInventory()
    private let previews = PreviewCapturer()
    private let session = MirrorSession()
    private let overlays = MirrorOverlayController()

    init() {
        hasScreenCaptureAccess = access.isGranted
        overlays.onUserClose = { [weak self] in self?.overlayWasClosed() }
        Task {
            await Self.waitUntilAppIsReady()
            await self.requestScreenRecordingAccessIfNeeded()
        }
    }

    var selectedWindow: WindowChoice? { windows.first { $0.id == selectedID } }
    var visibleWindows: [WindowChoice] {
        guard let selectedDisplayID else { return windows }
        return windows.filter { $0.displayID == selectedDisplayID }
    }

    func windows(on displayID: CGDirectDisplayID) -> [WindowChoice] {
        windows.filter { $0.displayID == displayID }
    }

    func select(_ choice: WindowChoice) {
        selectedID = choice.id
        selectedDisplayID = choice.displayID
        if !isMirroring { status = "Selected \(choice.app) · \(choice.title)" }
    }

    func selectDisplay(_ id: CGDirectDisplayID) {
        selectedDisplayID = id
    }

    func select(id: CGWindowID?) {
        guard let id, let choice = windows.first(where: { $0.id == id }) else {
            selectedID = nil
            if !isMirroring { status = "Select a window, then choose Pin." }
            return
        }
        select(choice)
    }

    func refreshWindows() async {
        // Preflight only. Inventory and thumbnail calls while access is denied
        // can make macOS show the system prompt again during this session.
        hasScreenCaptureAccess = access.preflight()
        guard hasScreenCaptureAccess else {
            windows = []
            displays = []
            if !isMirroring { status = access.statusWhileDenied }
            return
        }
        do {
            let snapshot = try await inventory.snapshot()
            displays = snapshot.displays
            windows = snapshot.windows
            reconcileSelection(with: snapshot)
            updateIdleStatus(hasWindows: !snapshot.windows.isEmpty)
        } catch {
            windows = []
            selectedID = nil
            status = "Could not list windows: \(error.localizedDescription)"
        }
    }

    func capturePreview(for choice: WindowChoice) async -> NSImage? {
        await previews.capture(window: choice.window)
    }

    func start() async {
        hasScreenCaptureAccess = access.preflight()
        guard hasScreenCaptureAccess else {
            status = "Screen Recording access is required to pin a window."
            return
        }
        guard let choice = selectedWindow else {
            status = "Select an app window first."
            return
        }
        await stop(resetStatus: false)

        mirrorGeneration += 1
        let generation = mirrorGeneration
        do {
            try await session.start(
                window: choice,
                onFrame: { [weak self] frame in self?.receive(frame, generation: generation) },
                onPaused: { [weak self] in self?.sourcePaused(generation: generation) },
                onStop: { [weak self] error in
                    Task { await self?.streamStopped(with: error, windowID: choice.id, generation: generation) }
                }
            )
            sourceDescription = "\(choice.app) · \(choice.title)"
            isMirroring = true
            isSourcePaused = false
            status = Self.pinnedStatus
            overlays.show(model: self)
            watchSource(id: choice.id, generation: generation)
        } catch {
            isMirroring = false
            sourceDescription = nil
            status = access.preflight()
                ? "Could not pin that window: \(error.localizedDescription)"
                : "Screen Recording access is required to pin a window."
        }
    }

    // MARK: - Live source monitoring

    private static let pinnedStatus = "Pinned on all displays and Spaces."

    private func receive(_ frame: NSImage, generation: Int) {
        guard isMirroring, generation == mirrorGeneration else { return }
        frames.image = frame
        if isSourcePaused {
            isSourcePaused = false
            status = Self.pinnedStatus
        }
    }

    private func sourcePaused(generation: Int) {
        guard isMirroring, generation == mirrorGeneration else { return }
        isSourcePaused = true
        status = "The pinned window isn't visible (minimized?). Restore it to resume."
    }

    private func streamStopped(with error: Error, windowID: CGWindowID, generation: Int) async {
        guard isMirroring, generation == mirrorGeneration else { return }
        let windowGone = !Self.windowExists(windowID)
        await stop(resetStatus: false)
        status = windowGone
            ? "The pinned window was closed. Choose another window to pin."
            : "Capture stopped: \(error.localizedDescription)"
    }

    /// ScreenCaptureKit doesn't reliably report a closed source window, so check
    /// once a second; also keep the capture size in step with the window size.
    private func watchSource(id: CGWindowID, generation: Int) {
        watchTask?.cancel()
        watchTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self, self.isMirroring, self.mirrorGeneration == generation else { return }
                guard let bounds = Self.windowBounds(id) else {
                    await self.stop(resetStatus: false)
                    self.status = "The pinned window was closed. Choose another window to pin."
                    return
                }
                await self.session.resize(to: bounds.size)
            }
        }
    }

    private static func windowInfo(_ id: CGWindowID) -> [String: Any]? {
        (CGWindowListCopyWindowInfo([.optionIncludingWindow], id) as? [[String: Any]])?.first
    }

    private static func windowExists(_ id: CGWindowID) -> Bool { windowInfo(id) != nil }

    private static func windowBounds(_ id: CGWindowID) -> CGRect? {
        guard let info = windowInfo(id) else { return nil }
        guard let dict = info[kCGWindowBounds as String] as? NSDictionary,
              let bounds = CGRect(dictionaryRepresentation: dict) else { return .zero }
        return bounds
    }

    func stop() async { await stop(resetStatus: true) }

    private func requestScreenRecordingAccessIfNeeded() async {
        guard !access.isGranted, !access.didRequestThisLaunch else { return }
        if !isMirroring { status = "macOS is asking for Screen Recording access." }
        NSApp.activate(ignoringOtherApps: true)
        let granted = access.requestIfNeeded()
        hasScreenCaptureAccess = granted
        if granted {
            await refreshWindows()
        } else if !isMirroring {
            status = "Screen Recording access was not granted."
        }
    }

    private func stop(resetStatus: Bool) async {
        watchTask?.cancel()
        watchTask = nil
        mirrorGeneration += 1
        await session.stop()
        isMirroring = false
        isSourcePaused = false
        sourceDescription = nil
        overlays.hide()
        frames.image = nil
        if resetStatus { status = "Choose a window to pin." }
    }

    func presentHelperWindow(openIfNeeded: () -> Void) {
        HelperWindow.userRequested = true
        if HelperWindow.focusExisting() { return }
        NSApp.activate(ignoringOtherApps: true)
        openIfNeeded()
    }

    /// Closing the pinned window unpins it: capture stops and the main window
    /// comes back with the same window still selected, so Return re-pins it.
    private func overlayWasClosed() {
        overlays.hide()
        presentHelperWindow { openMainWindow?() }
        Task {
            await stop(resetStatus: false)
            status = "Unpinned. Press Return or choose Pin to pin it again."
        }
    }

    private func reconcileSelection(with snapshot: WindowInventorySnapshot) {
        if let selectedDisplayID, !snapshot.displays.contains(where: { $0.id == selectedDisplayID }) {
            self.selectedDisplayID = nil
        }
        if self.selectedDisplayID == nil {
            let mainDisplayID = NSScreen.main?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
            let mainID = mainDisplayID?.uint32Value
            self.selectedDisplayID = snapshot.displays.first { $0.id == mainID }?.id ?? snapshot.displays.first?.id
        }
        if let selectedID, !snapshot.windows.contains(where: { $0.id == selectedID }) {
            self.selectedID = nil
        }
    }

    private func updateIdleStatus(hasWindows: Bool) {
        guard !isMirroring else { return }
        if let selectedWindow {
            status = "Selected \(selectedWindow.app) · \(selectedWindow.title)"
        } else if !hasWindows {
            status = "No eligible app windows found. Open an app window and refresh."
        } else {
            status = "Select a window, then choose Pin."
        }
    }

    private static func waitUntilAppIsReady() async {
        for _ in 0..<30 {
            if NSApp.isRunning { return }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }
}

@MainActor
final class FrameStore: ObservableObject {
    @Published var image: NSImage?
}
