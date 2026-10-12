// Draws Tempo's app icon into an .iconset folder. Usage: swift make-icon.swift <out.iconset>
// DESIGN.md 11.2: the nimbi cloud on the dark squircle, eyes looking right, one prop. Tempo's
// prop is a ring of time: an aurora arc three quarters of the way round the cloud, like the
// panel's ring.
import AppKit

let out = CommandLine.arguments[1]
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: alpha)
}

/// CloudShape (DESIGN.md 3.1): a circle with 8 soft, slightly uneven scallops.
func cloudPath(center c: CGPoint, radius r: CGFloat) -> CGPath {
    let path = CGMutablePath()
    for i in 0...240 {
        let t = Double(i) / 240 * 2 * .pi
        let lobe = pow(abs(cos(4 * t + 0.2)), 0.7)
        let k = 0.93 + 0.043 * (2 * lobe - 1) + 0.012 * sin(2 * t + 1)
        let p = CGPoint(x: c.x + r * k * cos(t), y: c.y + r * k * sin(t))
        i == 0 ? path.move(to: p) : path.addLine(to: p)
    }
    path.closeSubpath()
    return path
}

func radial(_ ctx: CGContext, _ center: CGPoint, _ radius: CGFloat, _ hex: UInt32, _ alpha: CGFloat) {
    let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                       colors: [color(hex, alpha), color(hex, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(g, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
}

/// The cloud in a size×size box whose top-left is `o` (y grows downward; the context is flipped).
func drawCloud(_ ctx: CGContext, at o: CGPoint, size s: CGFloat) {
    let center = CGPoint(x: o.x + s / 2, y: o.y + s / 2)
    let outline = cloudPath(center: center, radius: s / 2)
    // Violet glow: the outline at 1.1×, blurred.
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: s * 0.18, color: color(0xB07CFF, 0.7))
    ctx.addPath(cloudPath(center: center, radius: s / 2 * 1.04))
    ctx.setFillColor(color(0xB07CFF, 0.55))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(outline)
    ctx.clip()
    let base = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                          colors: [color(0x7FD0FF), color(0xB9B4FF), color(0xF3B6EC)] as CFArray,
                          locations: [0, 0.5, 1])!
    ctx.drawLinearGradient(base, start: CGPoint(x: o.x, y: o.y + s), end: CGPoint(x: o.x + s, y: o.y), options: [])
    radial(ctx, CGPoint(x: o.x + 0.12 * s, y: o.y + 0.5 * s), 0.55 * s, 0x56BFFF, 0.9)
    radial(ctx, CGPoint(x: o.x + 0.85 * s, y: o.y + 0.12 * s), 0.5 * s, 0xF6A9E4, 0.85)
    let core = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                          colors: [color(0xFFFFFF, 1), color(0xFFFFFF, 0.55), color(0xFFFFFF, 0)] as CFArray,
                          locations: [0, 0.5, 1])!
    let coreCenter = CGPoint(x: o.x + 0.44 * s, y: o.y + 0.62 * s)
    ctx.drawRadialGradient(core, startCenter: coreCenter, startRadius: 0, endCenter: coreCenter, endRadius: 0.36 * s, options: [])
    // Rim: a soft white edge inside the outline.
    ctx.setShadow(offset: .zero, blur: s * 0.035, color: color(0xFFFFFF, 0.7))
    ctx.addPath(outline)
    ctx.setStrokeColor(color(0xFFFFFF, 0.55))
    ctx.setLineWidth(s * 0.05)
    ctx.strokePath()
    ctx.restoreGState()

    // Face: 0.08·size right of center, looking right; the right eye a touch lower.
    let fx = center.x + s * 0.08 + s * 0.03, fy = center.y - s * 0.02
    let ew = s * 0.12, eh = s * 0.18, gap = s * 0.07
    for (i, ex) in [fx - gap / 2 - ew / 2, fx + gap / 2 + ew / 2].enumerated() {
        let ey = fy + (i == 1 ? s * 0.01 : 0)
        ctx.setFillColor(color(0x24163A))
        ctx.fillEllipse(in: CGRect(x: ex - ew / 2, y: ey - eh / 2, width: ew, height: eh))
        ctx.setFillColor(color(0xFFFFFF, 0.18))
        let hr = ew * 0.18
        ctx.fillEllipse(in: CGRect(x: ex + ew * 0.15 - hr, y: ey - eh * 0.2 - hr, width: hr * 2, height: hr * 2))
    }
}

/// The ring of time: a faint full track, then an aurora arc from the top, clockwise, three
/// quarters of the way round. Thick enough to survive at 16 px.
func ring(_ ctx: CGContext, center c: CGPoint, radius r: CGFloat, width w: CGFloat) {
    ctx.saveGState()
    ctx.setLineCap(.round)
    ctx.setLineWidth(w)
    ctx.setStrokeColor(color(0xFFFFFF, 0.08))
    ctx.addArc(center: c, radius: r, startAngle: 0, endAngle: 2 * .pi, clockwise: false)
    ctx.strokePath()
    // The context is flipped (y down), so increasing angles run clockwise on screen.
    let arc = CGMutablePath()
    arc.addArc(center: c, radius: r, startAngle: -.pi / 2, endAngle: .pi, clockwise: false)
    let stroked = arc.copy(strokingWithWidth: w, lineCap: .round, lineJoin: .round, miterLimit: 1)
    ctx.addPath(stroked)
    ctx.clip()
    let aurora = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                            colors: [color(0x7FD0FF), color(0xB9B4FF), color(0xF3B6EC)] as CFArray,
                            locations: [0, 0.5, 1])!
    ctx.drawLinearGradient(aurora, start: CGPoint(x: c.x - r, y: c.y + r), end: CGPoint(x: c.x + r, y: c.y - r), options: [])
    ctx.restoreGState()
}

func draw(_ px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = context
    let ctx = context.cgContext
    ctx.translateBy(x: 0, y: s)
    ctx.scaleBy(x: 1, y: -1)

    // Tile: rounded rect, radius 22.5% of its width, inset 10%, white 0.16 → 0.05, white 0.12 rim.
    let inset = s * 0.1, t = s - inset * 2
    let tile = CGPath(roundedRect: CGRect(x: inset, y: inset, width: t, height: t),
                      cornerWidth: t * 0.225, cornerHeight: t * 0.225, transform: nil)
    ctx.saveGState()
    ctx.addPath(tile)
    ctx.clip()
    let bg = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                        colors: [color(0x292929), color(0x0D0D0D)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: inset), end: CGPoint(x: 0, y: inset + t), options: [])

    // The cloud a touch smaller than usual (0.5 of the tile), so the ring fits round it.
    let size = t * 0.5
    let origin = CGPoint(x: s / 2 - size / 2, y: s / 2 - size / 2)
    ring(ctx, center: CGPoint(x: s / 2, y: s / 2), radius: t * 0.36, width: max(1.6, t * 0.055))
    drawCloud(ctx, at: origin, size: size)
    ctx.restoreGState()

    ctx.addPath(tile)
    ctx.setStrokeColor(color(0xFFFFFF, 0.12))
    ctx.setLineWidth(max(0.5, s * 0.006))
    ctx.strokePath()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for (name, px) in [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128),
                   ("128x128@2x", 256), ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024)] {
    try! draw(px).write(to: URL(fileURLWithPath: "\(out)/icon_\(name).png"))
}
