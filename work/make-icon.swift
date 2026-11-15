import AppKit

let size = 1024
let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
    guard let context = NSGraphicsContext.current?.cgContext else { return false }
    let colors = [
        NSColor(calibratedRed: 0.20, green: 0.33, blue: 0.86, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.10, green: 0.16, blue: 0.48, alpha: 1).cgColor
    ] as CFArray
    let space = CGColorSpaceCreateDeviceRGB()
    let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1])!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: size),
        end: CGPoint(x: size, y: 0),
        options: []
    )

    let card = CGRect(x: 212, y: 300, width: 600, height: 430)
    context.setShadow(offset: CGSize(width: 0, height: -18), blur: 36, color: NSColor.black.withAlphaComponent(0.28).cgColor)
    let cardPath = CGPath(roundedRect: card, cornerWidth: 48, cornerHeight: 48, transform: nil)
    context.setFillColor(NSColor(calibratedWhite: 0.96, alpha: 1).cgColor)
    context.addPath(cardPath)
    context.fillPath()
    context.setShadow(offset: .zero, blur: 0, color: nil)

    let bar = CGRect(x: card.minX, y: card.maxY - 78, width: card.width, height: 78)
    context.saveGState()
    context.addPath(cardPath)
    context.clip()
    context.setFillColor(NSColor(calibratedWhite: 0.90, alpha: 1).cgColor)
    context.fill(bar)
    context.restoreGState()

    for (index, color) in [NSColor.systemRed, NSColor.systemYellow, NSColor.systemGreen].enumerated() {
        let dot = CGRect(x: card.minX + 36 + CGFloat(index) * 34, y: card.maxY - 50, width: 18, height: 18)
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: dot)
    }

    let lineColor = NSColor(calibratedWhite: 0.78, alpha: 1).cgColor
    context.setFillColor(lineColor)
    for index in 0..<4 {
        let line = CGRect(x: card.minX + 48, y: card.minY + 70 + CGFloat(index) * 52, width: index == 3 ? 280 : 500, height: 18)
        context.addPath(CGPath(roundedRect: line, cornerWidth: 9, cornerHeight: 9, transform: nil))
        context.fillPath()
    }

    let pinHead = CGRect(x: 456, y: 690, width: 112, height: 112)
    context.setFillColor(NSColor(calibratedRed: 0.90, green: 0.27, blue: 0.29, alpha: 1).cgColor)
    context.setShadow(offset: CGSize(width: 0, height: -8), blur: 16, color: NSColor.black.withAlphaComponent(0.25).cgColor)
    context.fillEllipse(in: pinHead)
    context.setShadow(offset: .zero, blur: 0, color: nil)
    context.setFillColor(NSColor(calibratedWhite: 1, alpha: 0.35).cgColor)
    context.fillEllipse(in: CGRect(x: 486, y: 734, width: 36, height: 28))

    context.setFillColor(NSColor(calibratedRed: 0.72, green: 0.18, blue: 0.22, alpha: 1).cgColor)
    context.fill(CGRect(x: 500, y: 620, width: 24, height: 90))
    let tip = CGMutablePath()
    tip.move(to: CGPoint(x: 492, y: 620))
    tip.addLine(to: CGPoint(x: 532, y: 620))
    tip.addLine(to: CGPoint(x: 512, y: 575))
    tip.closeSubpath()
    context.addPath(tip)
    context.fillPath()
    return true
}

let data = image.tiffRepresentation!
let bitmap = NSBitmapImageRep(data: data)!
let png = bitmap.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
