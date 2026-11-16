import AppKit
import SwiftUI

@MainActor
final class MirrorOverlayController {
    /// One panel per connected display, keyed by display ID so a screen
    /// change only adds/removes the affected panels (user-resized ones stay put).
    private var panels: [CGDirectDisplayID: MirrorPanel] = [:]
    private weak var model: MirrorModel?
    private var spaceObserver: NSObjectProtocol?
    private var activationObserver: NSObjectProtocol?
    private var screenObserver: NSObjectProtocol?
    var onUserClose: (() -> Void)?

    func show(model: MirrorModel) {
        self.model = model
        syncPanelsWithScreens()
        installObservers()
    }

    func hide() {
        panels.values.forEach { $0.orderOut(nil) }
        panels.removeAll()
        model = nil
        removeObservers()
    }

    private func syncPanelsWithScreens() {
        guard let model else { return }
        var screensByID: [CGDirectDisplayID: NSScreen] = [:]
        for screen in NSScreen.screens {
            if let id = Self.displayID(of: screen) { screensByID[id] = screen }
        }
        for (id, panel) in panels where screensByID[id] == nil {
            panel.orderOut(nil)
            panels[id] = nil
        }
        for (id, screen) in screensByID {
            if let panel = panels[id] {
                // Display resolution/arrangement changed: keep the panel on its screen.
                if !screen.visibleFrame.intersects(panel.frame) {
                    panel.setFrame(Self.defaultFrame(on: screen), display: true)
                }
            } else {
                panels[id] = makePanel(on: screen, model: model)
            }
        }
        raise()
    }

    private func makePanel(on screen: NSScreen, model: MirrorModel) -> MirrorPanel {
        let panel = MirrorPanel(
            contentRect: Self.defaultFrame(on: screen),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        panel.title = "Pin To Top"
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications, .fullScreenAuxiliary, .stationary]
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.backgroundColor = .black
        panel.contentView = NSHostingView(rootView: MirrorPreview(frames: model.frames))
        panel.onUserClose = { [weak self] in self?.onUserClose?() }
        return panel
    }

    private static func defaultFrame(on screen: NSScreen) -> NSRect {
        let visible = screen.visibleFrame
        let width = min(420, max(260, visible.width - 48))
        let height = min(260, max(170, visible.height - 48))
        return NSRect(x: visible.maxX - width - 24, y: visible.maxY - height - 24, width: width, height: height)
    }

    private static func displayID(of screen: NSScreen) -> CGDirectDisplayID? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }

    private func installObservers() {
        removeObservers()
        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.raise() }
        }
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.raise() }
        }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.syncPanelsWithScreens() }
        }
    }

    private func removeObservers() {
        if let spaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(spaceObserver) }
        if let activationObserver { NotificationCenter.default.removeObserver(activationObserver) }
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        spaceObserver = nil
        activationObserver = nil
        screenObserver = nil
    }

    private func raise() {
        panels.values.forEach { $0.orderFrontRegardless() }
    }
}

private final class MirrorPanel: NSPanel {
    var onUserClose: (() -> Void)?

    override func close() {
        onUserClose?()
        super.close()
    }
}

struct MirrorPreview: View {
    @ObservedObject var frames: FrameStore

    var body: some View {
        ZStack {
            Color.black
            if let image = frames.image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
            } else {
                VStack(spacing: 8) {
                    ProgressView().tint(.white)
                    Text("Waiting for video…").foregroundStyle(.white.opacity(0.8)).font(.caption)
                }
            }
        }
        .frame(minWidth: 220, minHeight: 140)
        .ignoresSafeArea()
    }
}
