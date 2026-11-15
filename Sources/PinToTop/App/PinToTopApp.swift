import AppKit
import SwiftUI

@main
struct PinToTopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = MirrorModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarPicker(model: model)
        } label: {
            Label("Pin To Top", systemImage: model.isMirroring ? "pin.fill" : "pin")
        }
        .menuBarExtraStyle(.window)

        Window("Pin To Top", id: "main") {
            ContentView(model: model)
                .frame(minWidth: 640, minHeight: 480)
        }
        .defaultSize(width: 760, height: 560)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        for delay in [0.0, 0.2, 0.6] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                HelperWindow.suppressLaunchWindow()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

enum HelperWindow {
    static let title = "Pin To Top"
    static var userRequested = false

    static func isHelper(_ window: NSWindow) -> Bool {
        !(window is NSPanel) && window.title == title
    }

    static func existing() -> NSWindow? {
        NSApp.windows.first { window in
            isHelper(window) && (window.isVisible || window.isMiniaturized)
        }
    }

    @discardableResult
    static func focusExisting() -> Bool {
        guard let window = existing() else { return false }
        NSApp.activate(ignoringOtherApps: true)
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
        return true
    }

    static func suppressLaunchWindow() {
        guard !userRequested else { return }
        for window in NSApp.windows where isHelper(window) {
            window.close()
        }
    }
}
