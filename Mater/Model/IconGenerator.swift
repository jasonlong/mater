import AppKit

enum IconStyle {
    case filled   // work: solid bg, knockout text
    case outlined // break/stopped: stroke outline, solid text
}

struct IconGenerator {
    static func generate(text: String, style: IconStyle, size: NSSize = NSSize(width: 20, height: 20)) -> NSImage {
        let scale: CGFloat = 2
        let pixelSize = NSSize(width: size.width * scale, height: size.height * scale)

        let image = NSImage(size: size, flipped: false) { rect in
            let bitmapRep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int(pixelSize.width),
                pixelsHigh: Int(pixelSize.height),
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )!

            NSGraphicsContext.saveGraphicsState()
            let ctx = NSGraphicsContext(bitmapImageRep: bitmapRep)!
            NSGraphicsContext.current = ctx

            let scaledRect = NSRect(origin: .zero, size: pixelSize)
            let inset = scaledRect.insetBy(dx: 3, dy: 3)
            let notchSize: CGFloat = 7
            let cornerRadius: CGFloat = 3
            let midX = scaledRect.midX
            let strokeWidth: CGFloat = 2.5
            let fontSize = text.count > 1 ? 20.0 : 22.0

            let framePath = makeFramePath(
                rect: inset, midX: midX,
                notchSize: notchSize, cornerRadius: cornerRadius
            )

            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .bold),
                .foregroundColor: NSColor.black,
            ]

            switch style {
            case .filled:
                NSColor.black.setFill()
                framePath.fill()
                ctx.cgContext.setBlendMode(.destinationOut)
                drawCenteredText(text, in: inset, attributes: attrs, yOffset: notchSize / 2)
                ctx.cgContext.setBlendMode(.normal)

            case .outlined:
                NSColor.black.setStroke()
                framePath.lineWidth = strokeWidth
                framePath.stroke()
                drawCenteredText(text, in: inset, attributes: attrs, yOffset: notchSize / 2)
            }

            NSGraphicsContext.restoreGraphicsState()

            bitmapRep.draw(in: rect)
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func makeFramePath(
        rect: NSRect, midX: CGFloat,
        notchSize: CGFloat, cornerRadius r: CGFloat
    ) -> NSBezierPath {
        let path = NSBezierPath()

        // Top-left corner
        path.move(to: NSPoint(x: rect.minX, y: rect.maxY - r))
        path.appendArc(from: NSPoint(x: rect.minX, y: rect.maxY),
                      to: NSPoint(x: rect.minX + r, y: rect.maxY), radius: r)

        // Top-right corner
        path.line(to: NSPoint(x: rect.maxX - r, y: rect.maxY))
        path.appendArc(from: NSPoint(x: rect.maxX, y: rect.maxY),
                      to: NSPoint(x: rect.maxX, y: rect.maxY - r), radius: r)

        // Bottom-right corner
        path.line(to: NSPoint(x: rect.maxX, y: rect.minY + r))
        path.appendArc(from: NSPoint(x: rect.maxX, y: rect.minY),
                      to: NSPoint(x: rect.maxX - r, y: rect.minY), radius: r)

        // Bottom edge with notch
        path.line(to: NSPoint(x: midX + notchSize, y: rect.minY))
        path.line(to: NSPoint(x: midX, y: rect.minY + notchSize))
        path.line(to: NSPoint(x: midX - notchSize, y: rect.minY))

        // Bottom-left corner
        path.line(to: NSPoint(x: rect.minX + r, y: rect.minY))
        path.appendArc(from: NSPoint(x: rect.minX, y: rect.minY),
                      to: NSPoint(x: rect.minX, y: rect.minY + r), radius: r)

        path.close()
        return path
    }

    private static func drawCenteredText(
        _ text: String, in rect: NSRect,
        attributes: [NSAttributedString.Key: Any], yOffset: CGFloat
    ) {
        let str = text as NSString
        let strSize = str.size(withAttributes: attributes)
        let point = NSPoint(
            x: rect.minX + (rect.width - strSize.width) / 2,
            y: rect.minY + (rect.height - strSize.height) / 2 + yOffset
        )
        str.draw(at: point, withAttributes: attributes)
    }
}
