import AppKit

// swift tools/contact_sheet.swift <iphone-capture-directory> <output.png>
guard CommandLine.arguments.count == 3 else {
    fputs("Usage: swift tools/contact_sheet.swift <capture-directory> <output.png>\n", stderr)
    exit(1)
}

let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let size = NSSize(width: 1452, height: 1160)
let image = NSImage(size: size)
let shots = [("first-pigment.png", "01  /  DESPERTAR EL COLOR"),
             ("camp.png", "02  /  UN HOGAR CONTRA LA TINTA"),
             ("atlas.png", "03  /  EL MUNDO BAJO LAS PAGINAS")]
let ink = NSColor(red: 0.16, green: 0.19, blue: 0.21, alpha: 1)
func text(_ value: String, at point: NSPoint, size: CGFloat, color: NSColor) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont(name: "AvenirNext-DemiBold", size: size) ?? NSFont.systemFont(ofSize: size),
        .foregroundColor: color
    ]
    (value as NSString).draw(at: point, withAttributes: attributes)
}

image.lockFocus()
NSColor(red: 0.96, green: 0.94, blue: 0.88, alpha: 1).setFill()
NSRect(origin: .zero, size: size).fill()
text("NOTEBOOK  /  EL DESBORDE", at: NSPoint(x: 42, y: 1096), size: 34, color: ink)
text("Explora. Pinta. Sobrevive.     Capturas del simulador de iPhone.",
     at: NSPoint(x: 43, y: 1064), size: 18, color: ink.withAlphaComponent(0.65))
for (index, shot) in shots.enumerated() {
    guard let screenshot = NSImage(contentsOf: root.appendingPathComponent(shot.0)) else {
        fputs("Missing screenshot: \(shot.0)\n", stderr)
        exit(1)
    }
    let x = CGFloat(index) * 469 + 42
    let height = 430 * screenshot.size.height / screenshot.size.width
    screenshot.draw(in: NSRect(x: x, y: 1032 - height, width: 430, height: height))
    text(shot.1, at: NSPoint(x: x, y: 55), size: 15, color: ink)
}
image.unlockFocus()
guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
      let data = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Cannot encode contact sheet\n", stderr)
    exit(1)
}
do { try data.write(to: output) }
catch { fputs("Cannot save contact sheet: \(error.localizedDescription)\n", stderr); exit(1) }
