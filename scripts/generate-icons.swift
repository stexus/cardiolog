import AppKit
import Foundation

// Code-native placeholder icon; editable alongside the SwiftUI visual system.
for (name, dev) in [("AppIcon", false), ("AppIconDev", true)] {
    let image = NSImage(size: NSSize(width: 1024, height: 1024))
    image.lockFocus()
    NSColor(calibratedRed: dev ? 0.10 : 0.09, green: dev ? 0.20 : 0.38, blue: dev ? 0.38 : 0.85, alpha: 1).setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024)).fill()
    let path = NSBezierPath(); path.lineWidth = 44; path.lineCapStyle = .round; path.lineJoinStyle = .round
    path.move(to: NSPoint(x: 180, y: 500)); path.line(to: NSPoint(x: 340, y: 500)); path.line(to: NSPoint(x: 420, y: 660)); path.line(to: NSPoint(x: 515, y: 330)); path.line(to: NSPoint(x: 600, y: 540)); path.line(to: NSPoint(x: 665, y: 500)); path.line(to: NSPoint(x: 844, y: 500))
    NSColor.white.setStroke(); path.stroke()
    if dev { let text: NSString = "DEV"; text.draw(at: NSPoint(x: 390, y: 140), withAttributes: [.font: NSFont.systemFont(ofSize: 85, weight: .bold), .foregroundColor: NSColor.white]) }
    image.unlockFocus()
    let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
    let directory = URL(fileURLWithPath: "App/Assets.xcassets/\(name).appiconset")
    try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent("Icon.png"))
    let json = """
    {"images":[{"filename":"Icon.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"xcode","version":1}}
    """
    try json.write(to: directory.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
}
