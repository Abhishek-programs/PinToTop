// Draws the DMG window background: drag arrow + what to click on first launch.
// Usage: swift work/make-dmg-background.swift <output.png>
import AppKit

let out = CommandLine.arguments.dropFirst().first ?? "dmg-background.png"
let size = NSSize(width: 600, height: 400)   // points; drawn at 2x for Retina
let scale: CGFloat = 2

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = size

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

NSColor(calibratedWhite: 0.97, alpha: 1).setFill()
NSRect(origin: .zero, size: size).fill()

// Arrow between the app icon (x=150) and Applications (x=450), icons centered at y=175 from top.
let arrowY = size.height - 175
let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 235, y: arrowY))
arrow.line(to: NSPoint(x: 355, y: arrowY))
arrow.lineWidth = 4
arrow.lineCapStyle = .round
NSColor(calibratedWhite: 0.55, alpha: 1).setStroke()
arrow.stroke()
let head = NSBezierPath()
head.move(to: NSPoint(x: 340, y: arrowY + 12))
head.line(to: NSPoint(x: 358, y: arrowY))
head.line(to: NSPoint(x: 340, y: arrowY - 12))
head.lineWidth = 4
head.lineCapStyle = .round
head.lineJoinStyle = .round
head.stroke()

func draw(_ text: String, y: CGFloat, size fontSize: CGFloat, weight: NSFont.Weight, color: NSColor) {
    let style = NSMutableParagraphStyle()
    style.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: style,
    ]
    NSAttributedString(string: text, attributes: attrs)
        .draw(in: NSRect(x: 30, y: size.height - y - fontSize * 1.6, width: size.width - 60, height: fontSize * 1.6))
}

draw("Drag Pin To Top into Applications", y: 28, size: 20, weight: .semibold, color: .black)

// First-launch note box.
let box = NSRect(x: 40, y: 26, width: size.width - 80, height: 96)
NSColor(calibratedRed: 1, green: 0.96, blue: 0.85, alpha: 1).setFill()
NSBezierPath(roundedRect: box, xRadius: 10, yRadius: 10).fill()
let dark = NSColor(calibratedWhite: 0.15, alpha: 1)
draw("First launch: macOS will say it can't verify the app.", y: 292, size: 13, weight: .semibold, color: dark)
draw("Click Done (not Move to Trash), then open System Settings", y: 316, size: 13, weight: .regular, color: dark)
draw("→ Privacy & Security and click Open Anyway. Only once.", y: 336, size: 13, weight: .regular, color: dark)

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("Wrote \(out)")
