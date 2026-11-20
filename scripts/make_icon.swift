import AppKit
import CoreImage

// usage: make_icon.swift base.png out.png LABEL [hueRadians]
// Recolors the 1024px Claude icon and adds a dark label band at the bottom.
let args = CommandLine.arguments
let label = args[3]
let hueAngle = args.count > 4 ? Double(args[4]) ?? 3.45 : 3.45

let base = NSImage(contentsOfFile: args[1])!
var rect = NSRect(x: 0, y: 0, width: 1024, height: 1024)
let cg = base.cgImage(forProposedRect: &rect, context: nil, hints: nil)!

// Shift the orange body; the white starburst and black shadow are unaffected.
let hue = CIFilter(name: "CIHueAdjust")!
hue.setValue(CIImage(cgImage: cg), forKey: kCIInputImageKey)
hue.setValue(hueAngle, forKey: kCIInputAngleKey)
let shifted = CIContext().createCGImage(hue.outputImage!, from: CGRect(x: 0, y: 0, width: 1024, height: 1024))!

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024,
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSGraphicsContext.current!.cgContext.draw(shifted, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))

// Label band across the bottom of the rounded square (AppKit origin is bottom-left).
let square = NSRect(x: 100, y: 99, width: 824, height: 826)
NSBezierPath(roundedRect: square, xRadius: 185, yRadius: 185).addClip()
NSColor(calibratedRed: 0.06, green: 0.09, blue: 0.16, alpha: 1.0).setFill()
NSRect(x: 100, y: 99, width: 824, height: 215).fill()

let para = NSMutableParagraphStyle()
para.alignment = .center
var size: CGFloat = 150
var text: NSAttributedString
repeat {
    text = NSAttributedString(string: label, attributes: [
        .font: NSFont.systemFont(ofSize: size, weight: .heavy),
        .foregroundColor: NSColor.white,
        .kern: size * 0.09,
        .paragraphStyle: para,
    ])
    size -= 6
} while text.size().width > 740 && size > 40
let h = text.size().height
text.draw(in: NSRect(x: 100, y: 99 + (215 - h) / 2 + 4, width: 824, height: h))

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
