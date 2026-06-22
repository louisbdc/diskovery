// Génère l'image de fond du .dmg (fenêtre d'installation « glisser vers Applications »).
// Usage : swift icon/dmg-background.swift <sortie.png> <scale:1|2>
import AppKit

guard CommandLine.arguments.count >= 2 else {
    FileHandle.standardError.write(Data("usage: dmg-background.swift <out.png> [scale]\n".utf8))
    exit(1)
}
let outPath = CommandLine.arguments[1]
let scale = CommandLine.arguments.count >= 3 ? (Int(CommandLine.arguments[2]) ?? 1) : 1

let W: CGFloat = 600, H: CGFloat = 400

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(W) * scale, pixelsHigh: Int(H) * scale,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
rep.size = NSSize(width: W, height: H)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// Fond : léger dégradé blanc (bas) → bleu très clair (haut).
let gradient = NSGradient(
    starting: .white,
    ending: NSColor(calibratedRed: 0.91, green: 0.95, blue: 0.99, alpha: 1)
)!
gradient.draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: 90)

// Flèche horizontale (centrée sur la rangée d'icônes, y=200 depuis le haut).
let cy = H - 200
let arrow = NSColor(calibratedRed: 0.55, green: 0.62, blue: 0.72, alpha: 1)
arrow.setStroke()
arrow.setFill()
let shaft = NSBezierPath()
shaft.lineWidth = 10
shaft.lineCapStyle = .round
shaft.move(to: NSPoint(x: 250, y: cy))
shaft.line(to: NSPoint(x: 348, y: cy))
shaft.stroke()
let head = NSBezierPath()
head.move(to: NSPoint(x: 344, y: cy + 22))
head.line(to: NSPoint(x: 378, y: cy))
head.line(to: NSPoint(x: 344, y: cy - 22))
head.close()
head.fill()

// Textes (haut).
let para = NSMutableParagraphStyle()
para.alignment = .center
let ink = NSColor(calibratedRed: 0.24, green: 0.30, blue: 0.38, alpha: 1)

"Installer Diskovery".draw(
    in: NSRect(x: 0, y: H - 72, width: W, height: 32),
    withAttributes: [
        .font: NSFont.systemFont(ofSize: 22, weight: .semibold),
        .foregroundColor: ink,
        .paragraphStyle: para,
    ]
)
"Glissez l'icône dans le dossier Applications".draw(
    in: NSRect(x: 0, y: H - 100, width: W, height: 24),
    withAttributes: [
        .font: NSFont.systemFont(ofSize: 14, weight: .regular),
        .foregroundColor: ink.withAlphaComponent(0.8),
        .paragraphStyle: para,
    ]
)

NSGraphicsContext.restoreGraphicsState()

guard let data = rep.representation(using: .png, properties: [:]) else { exit(1) }
try! data.write(to: URL(fileURLWithPath: outPath))
