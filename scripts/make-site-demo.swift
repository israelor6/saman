// Run from the repository root: swift scripts/make-site-demo.swift
import AppKit
import AVFoundation

let width = 960
let height = 600
let fps: Int32 = 30
let duration = 10
let assets = URL(fileURLWithPath: "docs/assets", isDirectory: true)
let icon = NSImage(contentsOf: assets.appendingPathComponent("icon.png"))!
let bubbleSymbol = NSImage(systemSymbolName: "character.bubble.fill", accessibilityDescription: nil)!
    .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 27, weight: .semibold)
        .applying(NSImage.SymbolConfiguration(paletteColors: [.white, color(0x694BDE)])))!
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let pixelFormat = CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue

struct Copy {
    let locale: String
    let window: String
    let greeting: String
    let source: String
    let followUp: String
    let languages: String
    let translation: String
    let steps: [String]

    var rtl: Bool { locale == "he" }
}

let versions = [
    Copy(locale: "en", window: "Messages", greeting: "See you tomorrow!",
         source: "El tren llega al mediodía.", followUp: "I’ll meet you at the station.",
         languages: "Spanish  →  English", translation: "The train arrives at noon.",
         steps: ["Select the text", "Click the purple bubble", "Read the translation right there"]),
    Copy(locale: "es", window: "Mensajes", greeting: "¡Hasta mañana!",
         source: "The train arrives at noon.", followUp: "Nos vemos en la estación.",
         languages: "Inglés  →  Español", translation: "El tren llega al mediodía.",
         steps: ["Selecciona el texto", "Haz clic en la burbuja morada", "Lee la traducción ahí mismo"]),
    Copy(locale: "he", window: "הודעות", greeting: "נתראה מחר!",
         source: "The train arrives at noon.", followUp: "ניפגש בתחנה.",
         languages: "מאנגלית לעברית", translation: "הרכבת מגיעה לתחנה בצהריים.",
         steps: ["סמנו את הטקסט", "לחצו על הבועה הסגולה", "קראו את התרגום ליד הטקסט"])
]

func color(_ rgb: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat(rgb >> 16) / 255, green: CGFloat((rgb >> 8) & 255) / 255,
            blue: CGFloat(rgb & 255) / 255, alpha: alpha)
}

func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, radius: CGFloat, fill: UInt32,
         stroke: UInt32? = nil) {
    let path = NSBezierPath(roundedRect: NSRect(x: x, y: y, width: w, height: h), xRadius: radius, yRadius: radius)
    color(fill).setFill()
    path.fill()
    if let stroke {
        color(stroke).setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}

@discardableResult
func label(_ text: String, _ x: CGFloat, _ y: CGFloat, size: CGFloat, weight: NSFont.Weight = .regular,
           ink: UInt32 = 0xF8F5FF, align: NSTextAlignment = .left) -> CGFloat {
    let style = NSMutableParagraphStyle()
    style.alignment = align
    let run = NSAttributedString(string: text, attributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color(ink),
        .paragraphStyle: style
    ])
    let w = ceil(run.size().width)
    let offset = align == .right ? w : align == .center ? w / 2 : 0
    run.draw(in: NSRect(x: x - offset, y: y, width: w + 1, height: ceil(run.size().height) + 1))
    return w
}

func smooth(_ time: CGFloat, _ start: CGFloat, _ end: CGFloat) -> CGFloat {
    let t = min(1, max(0, (time - start) / (end - start)))
    return t * t * (3 - 2 * t)
}

func cursor(_ x: CGFloat, _ y: CGFloat, click: CGFloat) {
    if click > 0, click < 1 {
        let radius = 18 + click * 33
        let ring = NSBezierPath(ovalIn: NSRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
        color(0xE2D8FF, 1 - click).setStroke()
        ring.lineWidth = 4
        ring.stroke()
    }
    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: x, y: y))
    for (dx, dy) in [(1, 32), (8, 25), (14, 36), (20, 33), (14, 22), (25, 21)] {
        arrow.line(to: NSPoint(x: x + CGFloat(dx), y: y + CGFloat(dy)))
    }
    arrow.close()
    color(0xFFFCFF).setFill()
    color(0x1A1237).setStroke()
    arrow.lineWidth = 2.5
    arrow.lineJoinStyle = .round
    arrow.fill()
    arrow.stroke()
}

func draw(_ copy: Copy, at time: CGFloat, into context: CGContext) {
    context.saveGState()
    context.translateBy(x: 0, y: CGFloat(height))
    context.scaleBy(x: 1, y: -1)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
    defer {
        NSGraphicsContext.restoreGraphicsState()
        context.restoreGState()
    }

    let background = CGGradient(colorsSpace: colorSpace, colors: [
        color(0x30215C).cgColor, color(0x151229).cgColor
    ] as CFArray, locations: [0, 1])!
    context.drawLinearGradient(background, start: CGPoint(x: 200, y: 0), end: CGPoint(x: 790, y: 600), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

    let step = time < 2.68 ? 0 : time < 4.45 ? 1 : 2
    let stepColor: UInt32 = step == 2 ? 0xA3F2CE : 0xF8F5FF
    label(copy.steps[step], 480, 35, size: 37, weight: .semibold, ink: stepColor, align: .center)

    let alignment: NSTextAlignment = copy.rtl ? .right : .left
    box(100, 102, 760, 304, radius: 25, fill: 0x201935, stroke: 0x5B4D7D)
    icon.draw(in: NSRect(x: 805, y: 111, width: 33, height: 33),
              from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    for (index, rgb) in [0xFF827D, 0xF4C474, 0x93D6A8].enumerated() {
        box(125 + CGFloat(index) * 19, 122, 11, 11, radius: 5.5, fill: UInt32(rgb))
    }
    label(copy.window, 480, 114, size: 22, weight: .medium, ink: 0xD4C9EB, align: .center)
    box(101, 153, 758, 1, radius: 0, fill: 0x453959)

    let chatX: CGFloat = copy.rtl ? 820 : 140
    label(copy.greeting, chatX, 175, size: 25, ink: 0xACA0C6, align: alignment)
    let sourceX: CGFloat = copy.rtl ? 447 : 157
    let sourceFont = NSFont.systemFont(ofSize: 32, weight: .medium)
    let sourceWidth = ceil((copy.source as NSString).size(withAttributes: [.font: sourceFont]).width)
    let messageX = sourceX - 17
    let messageWidth = sourceWidth + 34
    box(messageX, 211, messageWidth, 57, radius: 15, fill: 0x382D53)
    let selection = smooth(time, 1.15, 2.35)
    if selection > 0 {
        box(sourceX - 5, 220, (sourceWidth + 10) * selection, 39, radius: 5, fill: 0x6446BF)
    }
    label(copy.source, sourceX, 220, size: 32, weight: .medium)
    label(copy.followUp, chatX, 288, size: 25, ink: 0xACA0C6, align: alignment)

    let bubbleX = copy.rtl ? messageX - 67 : messageX + messageWidth + 13
    let bubbleOpacity = smooth(time, 2.35, 2.68)
    let press = smooth(time, 4, 4.10) - smooth(time, 4.10, 4.26)
    if bubbleOpacity > 0 {
        context.saveGState()
        context.setAlpha(bubbleOpacity)
        let inset = press * 3
        box(bubbleX + inset, 212 + inset, 54 - 2 * inset, 54 - 2 * inset,
            radius: 14, fill: 0x694BDE, stroke: 0xAF9AFF)
        let symbolSize = 30 - inset * 2
        bubbleSymbol.draw(in: NSRect(x: bubbleX + 27 - symbolSize / 2, y: 239 - symbolSize / 2,
                                    width: symbolSize, height: symbolSize),
                          from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        context.restoreGState()
    }

    let result = smooth(time, 4.15, 4.62)
    if result > 0 {
        context.saveGState()
        context.setAlpha(result)
        let panelWidth: CGFloat = 512
        let panelX: CGFloat = copy.rtl ? 308 : 140
        let panelY = 276 + (1 - result) * 12
        box(panelX + 2, panelY + 6, panelWidth, 114, radius: 19, fill: 0x130E23)
        box(panelX, panelY, panelWidth, 114, radius: 19, fill: 0x33264E, stroke: 0x8976BA)
        let textX = copy.rtl ? panelX + panelWidth - 22 : panelX + 22
        label(copy.languages, textX, panelY + 13, size: 20, weight: .semibold, ink: 0xCDBCF9, align: alignment)
        box(panelX + 22, panelY + 46, panelWidth - 44, 1, radius: 0, fill: 0x625581)
        label(copy.translation, textX, panelY + 57, size: 33, weight: .semibold, align: alignment)
        context.restoreGState()
    }

    let pointerOpacity = 1 - smooth(time, 4.48, 4.92)
    if pointerOpacity > 0 {
        let approach = smooth(time, 0.1, 1.15)
        let toBubble = smooth(time, 2.85, 4)
        let dragX = sourceX - 5 + (sourceWidth + 10) * selection
        let initialX = copy.rtl ? CGFloat(670) : 420
        let initialY = 365 - 127 * approach
        let x = initialX + (dragX - initialX) * approach
        context.saveGState()
        context.setAlpha(pointerOpacity)
        cursor(x + (bubbleX + 27 - x) * toBubble, initialY + toBubble,
               click: max(0, (time - 4) / 0.42))
        context.restoreGState()
    }

}

enum RenderError: Error {
    case writer, frame, poster
}

func render(_ copy: Copy) throws {
    let output = assets.appendingPathComponent("demo-\(copy.locale).mp4")
    let poster = assets.appendingPathComponent("demo-\(copy.locale).jpg")
    let directory = try FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask,
                                                appropriateFor: output, create: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let temporary = directory.appendingPathComponent(output.lastPathComponent)

    let writer = try AVAssetWriter(outputURL: temporary, fileType: .mp4)
    writer.shouldOptimizeForNetworkUse = true
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height,
        AVVideoCompressionPropertiesKey: [
            AVVideoAverageBitRateKey: 1_050_000, AVVideoProfileLevelKey: AVVideoProfileLevelH264MainAutoLevel
        ]
    ])
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height,
        kCVPixelBufferCGImageCompatibilityKey as String: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
    ])
    writer.add(input)
    guard writer.startWriting() else { throw writer.error ?? RenderError.writer }
    writer.startSession(atSourceTime: .zero)

    guard let pool = adaptor.pixelBufferPool else { throw RenderError.frame }
    for frame in 0..<(Int(fps) * duration) {
        while !input.isReadyForMoreMediaData {
            guard writer.status == .writing else { throw writer.error ?? RenderError.writer }
            Thread.sleep(forTimeInterval: 0.005)
        }
        try autoreleasepool {
            var buffer: CVPixelBuffer?
            guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) == kCVReturnSuccess,
                  let buffer else { throw RenderError.frame }
            CVPixelBufferLockBaseAddress(buffer, [])
            let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: width, height: height,
                                    bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                    space: colorSpace, bitmapInfo: pixelFormat)
            guard let context else {
                CVPixelBufferUnlockBaseAddress(buffer, [])
                throw RenderError.frame
            }
            draw(copy, at: CGFloat(frame) / CGFloat(fps), into: context)
            CVPixelBufferUnlockBaseAddress(buffer, [])
            guard adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(frame), timescale: fps)) else {
                throw writer.error ?? RenderError.frame
            }
        }
    }
    input.markAsFinished()
    writer.endSession(atSourceTime: CMTime(seconds: Double(duration), preferredTimescale: fps))
    let completion = DispatchSemaphore(value: 0)
    writer.finishWriting { completion.signal() }
    completion.wait()
    guard writer.status == .completed else { throw writer.error ?? RenderError.writer }

    guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: colorSpace, bitmapInfo: pixelFormat) else { throw RenderError.poster }
    draw(copy, at: CGFloat(duration), into: context)
    guard let image = context.makeImage(),
          let jpeg = NSBitmapImageRep(cgImage: image).representation(using: .jpeg, properties: [.compressionFactor: 0.87])
    else { throw RenderError.poster }
    if FileManager.default.fileExists(atPath: output.path) {
        _ = try FileManager.default.replaceItemAt(output, withItemAt: temporary)
    } else {
        try FileManager.default.moveItem(at: temporary, to: output)
    }
    try jpeg.write(to: poster, options: .atomic)
    print("Rendered \(copy.locale)")
}

for copy in versions {
    try render(copy)
}
