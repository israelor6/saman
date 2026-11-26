import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)

func color(_ rgb: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat((rgb >> 16) & 255) / 255,
            green: CGFloat((rgb >> 8) & 255) / 255,
            blue: CGFloat(rgb & 255) / 255, alpha: 1)
}

func box(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: CGRect(x: x, y: y, width: width, height: height),
           cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func bubble(_ context: CGContext, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat,
            tailOnLeft: Bool, fill: UInt32) {
    context.setFillColor(color(fill))
    context.addPath(box(x, y, width, height, 47))
    let side = tailOnLeft ? x + 49 : x + width - 47
    let sign: CGFloat = tailOnLeft ? 1 : -1
    context.move(to: CGPoint(x: side, y: y + 18))
    context.addLine(to: CGPoint(x: side, y: y - 28))
    context.addQuadCurve(to: CGPoint(x: side + sign * 13, y: y - 34),
                         control: CGPoint(x: side, y: y - 40))
    context.addLine(to: CGPoint(x: side + sign * 67, y: y + 12))
    context.closePath()
    context.fillPath()
}

func arrow(_ context: CGContext, from x1: CGFloat, to x2: CGFloat, y: CGFloat, stroke: UInt32) {
    let direction: CGFloat = x2 > x1 ? 1 : -1
    context.setStrokeColor(color(stroke))
    context.setLineWidth(15)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.move(to: CGPoint(x: x1, y: y))
    context.addLine(to: CGPoint(x: x2, y: y))
    context.move(to: CGPoint(x: x2 - 27 * direction, y: y + 27))
    context.addLine(to: CGPoint(x: x2, y: y))
    context.addLine(to: CGPoint(x: x2 - 27 * direction, y: y - 27))
    context.strokePath()
}

func render(_ pixels: Int) -> Data? {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
                                  bytesPerRow: pixels * 4, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    let plate = box(88, 88, 848, 848, 205)

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -15), blur: 34, color: color(0x171135).copy(alpha: 0.33))
    context.setFillColor(color(0x26216B))
    context.addPath(plate)
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(plate)
    context.clip()
    let gradient = CGGradient(colorsSpace: space, colors: [color(0x7364FF), color(0x4136D0), color(0x1C1954)] as CFArray,
                              locations: [0, 0.54, 1])!
    context.drawLinearGradient(gradient, start: CGPoint(x: 180, y: 930), end: CGPoint(x: 810, y: 98), options: [])
    for radius in [330.0, 414.0, 502.0] {
        context.setLineWidth(2)
        context.setStrokeColor(color(0xFFFFFF).copy(alpha: 0.16)!)
        context.strokeEllipse(in: CGRect(x: 525 - radius, y: 540 - radius, width: radius * 2, height: radius * 2))
    }
    context.restoreGState()

    bubble(context, x: 419, y: 321, width: 342, height: 224, tailOnLeft: false, fill: 0x8BF2C9)
    arrow(context, from: 675, to: 527, y: 419, stroke: 0x1F3E47)
    bubble(context, x: 262, y: 504, width: 352, height: 225, tailOnLeft: true, fill: 0xFFF7E4)
    arrow(context, from: 356, to: 518, y: 617, stroke: 0x3D31B1)

    guard let image = context.makeImage() else { return nil }
    return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
}

try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for side in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let suffix = scale == 2 ? "@2x" : ""
        guard let png = render(side * scale) else { fatalError("Could not render app icon.") }
        try png.write(to: output.appendingPathComponent("icon_\(side)x\(side)\(suffix).png"))
    }
}
