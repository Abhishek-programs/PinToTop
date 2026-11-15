import AppKit
import SwiftUI

@MainActor
final class MirrorOverlayController {
    private var panels: [MirrorPanel] = []
    private var spaceObserver: NSObjectProtocol?
    private var activationObserver: NSObjectProtocol?
    var onUserClose: (() -> Void)?

    func show(model: MirrorModel) {
        panels = NSScreen.screens.map { screen in
            let visible = screen.visibleFrame
            let width = min(420, max(260, visible.width - 48))
            let height = min(260, max(170, visible.height - 48))
            let frame = NSRect(
                x: visible.maxX - width - 24,
                y: visible.maxY - height - 24,
                width: width,
                height: height
            )

            let panel = MirrorPanel(
                contentRect: frame,
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
            panel.contentView = NSHostingView(rootView: MirrorPreview(model: model))
            panel.onUserClose = { [weak self] in self?.onUserClose?() }
            panel.orderFrontRegardless()
            return panel
        }
        installObservers()
    }

    func hide() {
        panels.forEach { $0.orderOut(nil) }
        panels.removeAll()
        removeObservers()
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
    }

    private func removeObservers() {
        if let spaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(spaceObserver) }
        if let activationObserver { NotificationCenter.default.removeObserver(activationObserver) }
        spaceObserver = nil
        activationObserver = nil
    }

    private func raise() {
        panels.forEach { $0.orderFrontRegardless() }
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
    @ObservedObject var model: MirrorModel

    var body: some View {
        ZStack {
            Color.black
            if let image = model.image {
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
