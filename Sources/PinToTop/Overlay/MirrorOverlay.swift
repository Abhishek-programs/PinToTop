import AppKit
import SwiftUI

@MainActor
final class MirrorOverlayController {
    /// One panel per display when true; otherwise a single panel that opens
    /// on the display under the pointer and can be dragged anywhere.
    /// Changing it while pinned switches modes live.
    var showsOnAllDisplays = false {
        didSet {
            guard oldValue != showsOnAllDisplays, model != nil else { return }
            switchMode()
        }
    }

    private var panel: MirrorPanel?                                  // one-display mode
    private var panels: [CGDirectDisplayID: MirrorPanel] = [:]       // all-displays mode
    private weak var model: MirrorModel?
    private var spaceObserver: NSObjectProtocol?
    private var activationObserver: NSObjectProtocol?
    private var screenObserver: NSObjectProtocol?
    var onUserClose: (() -> Void)?

    func show(model: MirrorModel) {
        self.model = model
        syncPanels()
        installObservers()
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
        panels.values.forEach { $0.orderOut(nil) }
        panels.removeAll()
        model = nil
        removeObservers()
    }

    /// Keeps the panel the user is looking at (and its size/position) when
    /// switching, and adds or removes the rest.
    private func switchMode() {
        if showsOnAllDisplays {
            if let panel, let id = Self.displayID(of: Self.screen(containing: panel.frame)) {
                panels[id] = panel
            } else {
                panel?.orderOut(nil)
            }
            panel = nil
        } else {
            let keepID = Self.displayID(of: Self.screenWithPointer())
            for (id, p) in panels where id != keepID { p.orderOut(nil) }
            panel = keepID.flatMap { panels[$0] }
            panels.removeAll()
        }
        syncPanels()
    }

    /// Creates missing panels and keeps existing ones on a connected screen.
    /// Also runs when displays are plugged in or removed.
    private func syncPanels() {
        guard let model else { return }
        if showsOnAllDisplays {
            var screensByID: [CGDirectDisplayID: NSScreen] = [:]
            for screen in NSScreen.screens {
                if let id = Self.displayID(of: screen) { screensByID[id] = screen }
            }
            for (id, p) in panels where screensByID[id] == nil {
                p.orderOut(nil)
                panels[id] = nil
            }
            for (id, screen) in screensByID {
                if let p = panels[id] {
                    if !screen.visibleFrame.intersects(p.frame) {
                        p.setFrame(Self.defaultFrame(on: screen), display: true)
                    }
                } else {
                    panels[id] = makePanel(on: screen, model: model)
                }
            }
        } else if let panel {
            if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(panel.frame) }),
               let screen = Self.screenWithPointer() {
                panel.setFrame(Self.defaultFrame(on: screen), display: true)
            }
        } else if let screen = Self.screenWithPointer() {
            panel = makePanel(on: screen, model: model)
        }
        raise()
    }

    private static func screenWithPointer() -> NSScreen? {
        let point = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
            ?? NSScreen.main ?? NSScreen.screens.first
    }

    private static func screen(containing frame: NSRect) -> NSScreen? {
        NSScreen.screens.max { a, b in
            a.frame.intersection(frame).width * a.frame.intersection(frame).height
                < b.frame.intersection(frame).width * b.frame.intersection(frame).height
        }
    }

    private static func displayID(of screen: NSScreen?) -> CGDirectDisplayID? {
        (screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
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
            Task { @MainActor [weak self] in self?.syncPanels() }
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
