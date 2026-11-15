import AppKit
import SwiftUI

@MainActor
final class MirrorModel: ObservableObject {
    @Published private(set) var windows: [WindowChoice] = []
    @Published private(set) var displays: [DisplayChoice] = []
    @Published private(set) var hasScreenCaptureAccess: Bool
    @Published var selectedDisplayID: CGDirectDisplayID?
    @Published var selectedID: CGWindowID?
    @Published var image: NSImage?
    @Published var status = "Choose a window to pin."
    @Published var isMirroring = false
    @Published private(set) var sourceDescription: String?
    @Published var stopFocusRequest = 0

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

        do {
            try await session.start(window: choice) { [weak self] frame in
                self?.image = frame
            }
            sourceDescription = "\(choice.app) · \(choice.title)"
            isMirroring = true
            status = "Pinned on all displays and Spaces."
            overlays.show(model: self)
        } catch {
            isMirroring = false
            sourceDescription = nil
            status = "Could not pin that window. Screen Recording access is required."
        }
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
        await session.stop()
        isMirroring = false
        sourceDescription = nil
        overlays.hide()
        image = nil
        if resetStatus { status = "Choose a window to pin." }
    }

    func presentHelperWindow(openIfNeeded: () -> Void) {
        HelperWindow.userRequested = true
        if HelperWindow.focusExisting() { return }
        NSApp.activate(ignoringOtherApps: true)
        openIfNeeded()
    }

    private func overlayWasClosed() {
        overlays.hide()
        status = "Still pinned. Choose Unpin in the menu bar."
        guard HelperWindow.focusExisting() else { return }
        stopFocusRequest += 1
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
