import AppKit
import CoreGraphics
import ScreenCaptureKit

/// Lists on-screen app windows for every connected display.
///
/// ScreenCaptureKit's on-screen filter follows the display the app is on.
/// WindowServer's on-screen list includes every display, so those IDs are
/// matched against the full shareable-window inventory.
@MainActor
final class WindowInventory {
    private var appIconCache: [String: NSImage] = [:]
    private let excludedBundleIdentifiers: Set<String> = [
        "com.apple.dock",
        "com.apple.controlcenter",
        "com.apple.notificationcenterui",
        "com.apple.systemuiserver",
        "com.apple.WindowManager",
        "com.apple.loginwindow",
        "com.apple.screencaptureui",
        "com.apple.universalaccessAuthWarn",
        "com.apple.TextInputMenuAgent",
        "com.apple.CoreServicesUIAgent"
    ]

    func snapshot() async throws -> WindowInventorySnapshot {
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
        let listed = onScreenWindowRecords()
        let displays = connectedDisplays()
        let shareable = Dictionary(content.windows.map { ($0.windowID, $0) }, uniquingKeysWith: { current, _ in current })
        let normalLayer = Int(CGWindowLevelForKey(.normalWindow))
        let windows = listed.values.compactMap { record -> WindowChoice? in
            guard record.layer == normalLayer,
                  record.bounds.width >= 120,
                  record.bounds.height >= 80,
                  let window = shareable[record.id],
                  let owner = window.owningApplication,
                  NSRunningApplication(processIdentifier: owner.processID)?.activationPolicy == .regular,
                  owner.bundleIdentifier != Bundle.main.bundleIdentifier,
                  !excludedBundleIdentifiers.contains(owner.bundleIdentifier) else { return nil }
            let bundleID = owner.bundleIdentifier
            let displayID = display(for: record.bounds, displays: displays)?.id ?? displays.first?.id
            guard let displayID else { return nil }

            return WindowChoice(
                id: window.windowID,
                title: trimmedTitle(window.title),
                app: owner.applicationName,
                bundleIdentifier: bundleID,
                appIcon: appIcon(for: bundleID),
                size: record.bounds.size,
                displayID: displayID,
                window: window
            )
        }
        .sorted {
            ($0.app + $0.title).localizedCaseInsensitiveCompare($1.app + $1.title) == .orderedAscending
        }
        return WindowInventorySnapshot(displays: displays, windows: windows)
    }

    private func trimmedTitle(_ title: String?) -> String {
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Untitled window" : trimmed
    }

    private func connectedDisplays() -> [DisplayChoice] {
        NSScreen.screens.compactMap { screen -> (CGDirectDisplayID, CGRect)? in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
            let id = CGDirectDisplayID(number.uint32Value)
            return (id, CGDisplayBounds(id))
        }
        .sorted { lhs, rhs in
            lhs.1.minX == rhs.1.minX ? lhs.1.minY < rhs.1.minY : lhs.1.minX < rhs.1.minX
        }
        .enumerated()
        .map { index, item in
            DisplayChoice(id: item.0, name: "Screen \(index + 1)", frame: item.1)
        }
    }

    private struct ListedWindow {
        let id: CGWindowID
        let bounds: CGRect
        let layer: Int
    }

    private func onScreenWindowRecords() -> [CGWindowID: ListedWindow] {
        let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
        guard let info = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return [:] }
        var records: [CGWindowID: ListedWindow] = [:]
        for item in info {
            guard let number = item[kCGWindowNumber as String] as? NSNumber,
                  let layer = item[kCGWindowLayer as String] as? NSNumber,
                  let boundsInfo = item[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsInfo) else { continue }
            let id = CGWindowID(number.uint32Value)
            records[id] = ListedWindow(id: id, bounds: bounds, layer: layer.intValue)
        }
        return records
    }

    private func display(for frame: CGRect, displays: [DisplayChoice]) -> DisplayChoice? {
        guard !displays.isEmpty else { return nil }
        let best = displays.max { lhs, rhs in
            frame.intersection(lhs.frame).area < frame.intersection(rhs.frame).area
        }
        if let best, frame.intersection(best.frame).area > 0 { return best }
        return displays.min { lhs, rhs in
            hypot(frame.midX - lhs.frame.midX, frame.midY - lhs.frame.midY)
                < hypot(frame.midX - rhs.frame.midX, frame.midY - rhs.frame.midY)
        }
    }

    private func appIcon(for bundleIdentifier: String) -> NSImage {
        if let cached = appIconCache[bundleIdentifier] { return cached }
        let icon: NSImage
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            icon = NSWorkspace.shared.icon(forFile: appURL.path)
        } else {
            icon = NSImage(systemSymbolName: "app", accessibilityDescription: "App icon") ?? NSImage(size: NSSize(width: 32, height: 32))
        }
        appIconCache[bundleIdentifier] = icon
        return icon
    }
}

private extension CGRect {
    var area: CGFloat { max(0, width) * max(0, height) }
}
