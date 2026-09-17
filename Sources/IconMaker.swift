import AppKit

let output = CommandLine.arguments[1]
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

let canvas = NSRect(origin: .zero, size: size)
let background = NSBezierPath(roundedRect: canvas.insetBy(dx: 44, dy: 44), xRadius: 210, yRadius: 210)
NSColor(calibratedRed: 0.13, green: 0.38, blue: 0.95, alpha: 1).setFill()
background.fill()

let page = NSBezierPath(roundedRect: NSRect(x: 190, y: 172, width: 644, height: 680), xRadius: 88, yRadius: 88)
NSColor.white.setFill()
page.fill()

let header = NSBezierPath(roundedRect: NSRect(x: 190, y: 650, width: 644, height: 202), xRadius: 88, yRadius: 88)
NSColor(calibratedRed: 0.97, green: 0.20, blue: 0.25, alpha: 1).setFill()
header.fill()
NSRect(x: 190, y: 650, width: 644, height: 101).fill()

let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 370, weight: .bold),
    .foregroundColor: NSColor(calibratedWhite: 0.12, alpha: 1)
]
let number = "31" as NSString
let numberSize = number.size(withAttributes: attributes)
number.draw(at: NSPoint(x: (1024 - numberSize.width) / 2, y: 235), withAttributes: attributes)

image.unlockFocus()
let representation = NSBitmapImageRep(data: image.tiffRepresentation!)!
let data = representation.representation(using: .png, properties: [:])!
try data.write(to: URL(fileURLWithPath: output))
