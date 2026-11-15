import AppKit
import CoreGraphics
import ScreenCaptureKit

struct DisplayChoice: Identifiable, Hashable {
    let id: CGDirectDisplayID
    let name: String
    let frame: CGRect

    static func == (lhs: DisplayChoice, rhs: DisplayChoice) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct WindowChoice: Identifiable, Hashable {
    let id: CGWindowID
    let title: String
    let app: String
    let bundleIdentifier: String
    let appIcon: NSImage
    let size: CGSize
    let displayID: CGDirectDisplayID
    let window: SCWindow

    static func == (lhs: WindowChoice, rhs: WindowChoice) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct WindowInventorySnapshot {
    let displays: [DisplayChoice]
    let windows: [WindowChoice]
}
