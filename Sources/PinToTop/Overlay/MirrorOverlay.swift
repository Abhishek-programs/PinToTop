import AppKit
import SwiftUI

@MainActor
final class MirrorOverlayController {
    /// A single panel, opened on the display the pointer is on. The user can
    /// drag it to another display; it follows Spaces on whichever display it's on.
    private var panel: MirrorPanel?
    private weak var model: MirrorModel?
    private var spaceObserver: NSObjectProtocol?
    private var activationObserver: NSObjectProtocol?
    private var screenObserver: NSObjectProtocol?
    var onUserClose: (() -> Void)?

    func show(model: MirrorModel) {
        self.model = model
        if panel == nil, let screen = Self.screenWithPointer() {
            panel = makePanel(on: screen, model: model)
        }
        raise()
        installObservers()
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
        model = nil
        removeObservers()
    }

    /// Displays changed (e.g. HDMI unplugged): if the panel is now off every
    /// screen, bring it back to the corner of the display the pointer is on.
    private func keepPanelOnScreen() {
        guard let panel else { return }
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(panel.frame) }),
           let screen = Self.screenWithPointer() {
            panel.setFrame(Self.defaultFrame(on: screen), display: true)
        }
        raise()
    }

    private static func screenWithPointer() -> NSScreen? {
        let point = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
            ?? NSScreen.main ?? NSScreen.screens.first
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
            Task { @MainActor [weak self] in self?.keepPanelOnScreen() }
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
        panel?.orderFrontRegardless()
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
