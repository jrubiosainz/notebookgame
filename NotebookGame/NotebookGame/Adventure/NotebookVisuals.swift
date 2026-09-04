import SpriteKit
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// The adventure uses the original drawings; pigment is a wash, not replacement art.
enum NotebookVisuals {
    static let paper = SKColor(red: 0.96, green: 0.94, blue: 0.88, alpha: 1)
    static let ink = SKColor(red: 0.16, green: 0.19, blue: 0.21, alpha: 1)
    static let muted = SKColor(red: 0.43, green: 0.45, blue: 0.43, alpha: 1)
    static let blue = SKColor(red: 0.26, green: 0.49, blue: 0.59, alpha: 1)
    static let gold = SKColor(red: 0.80, green: 0.55, blue: 0.22, alpha: 1)
    private static var textures: [String: SKTexture] = [:]

    static func color(_ pigment: Pigment) -> SKColor {
        switch pigment {
        case .brown: return SKColor(red: 0.67, green: 0.40, blue: 0.22, alpha: 1)
        case .green: return SKColor(red: 0.38, green: 0.61, blue: 0.39, alpha: 1)
        case .yellow: return SKColor(red: 0.94, green: 0.73, blue: 0.22, alpha: 1)
        case .red: return SKColor(red: 0.82, green: 0.33, blue: 0.28, alpha: 1)
        case .blue: return blue
        case .violet: return SKColor(red: 0.58, green: 0.41, blue: 0.67, alpha: 1)
        }
    }

    static func texture(_ name: String, folder: String) -> SKTexture {
        let key = "\(folder)/\(name)"
        if let cached = textures[key] { return cached }
        #if canImport(UIKit)
        let root = Bundle.main.resourceURL!.appendingPathComponent("assets")
        guard let image = UIImage(contentsOfFile: root.appendingPathComponent(key + ".png").path) else {
            fatalError("Missing notebook artwork: \(key)")
        }
        #else
        let root = ProcessInfo.processInfo.environment["NOTEBOOK_ASSETS"]
            ?? FileManager.default.currentDirectoryPath + "/assets"
        guard let image = NSImage(contentsOfFile: root + "/" + key + ".png") else {
            fatalError("Missing notebook artwork: \(key)")
        }
        #endif
        let value = SKTexture(image: image)
        value.filteringMode = .linear
        value.usesMipmaps = true
        textures[key] = value
        return value
    }

    static func sprite(_ name: String, folder: String = "props", height: CGFloat) -> SKSpriteNode {
        let texture = texture(name, folder: folder)
        let node = SKSpriteNode(texture: texture)
        node.size = CGSize(width: height * texture.size().width / max(1, texture.size().height),
                           height: height)
        return node
    }

    static func label(_ text: String, size: CGFloat = 16, color: SKColor = ink,
                      sans: Bool = false) -> SKLabelNode {
        let node = SKLabelNode(fontNamed: sans ? "AvenirNext-DemiBold" : "ChalkboardSE-Regular")
        node.text = text
        node.fontSize = size
        node.fontColor = color
        node.verticalAlignmentMode = .center
        return node
    }

    static func text(_ text: String, width: CGFloat, size: CGFloat = 16,
                     color: SKColor = ink) -> SKLabelNode {
        let node = label(text, size: size, color: color)
        node.numberOfLines = 0
        node.preferredMaxLayoutWidth = width
        node.lineBreakMode = .byWordWrapping
        return node
    }

    static func card(_ size: CGSize, fill: SKColor = paper, radius: CGFloat = 12) -> SKShapeNode {
        let shape = SKShapeNode(rectOf: size, cornerRadius: radius)
        shape.fillColor = fill
        shape.strokeColor = ink.withAlphaComponent(0.65)
        shape.lineWidth = 1.3
        return shape
    }

    static func rule(width: CGFloat, color: SKColor = muted) -> SKShapeNode {
        let path = CGMutablePath()
        for i in 0...24 {
            let x = CGFloat(i) / 24 * width - width / 2
            let p = CGPoint(x: x, y: sin(CGFloat(i) * 1.3) * 0.55)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        let node = SKShapeNode(path: path)
        node.strokeColor = color
        node.lineWidth = 0.8
        return node
    }

    static func wash(radius: CGFloat, color: SKColor, seed: Int = 0) -> SKShapeNode {
        let path = CGMutablePath()
        for i in 0...36 {
            let a = CGFloat(i) / 36 * .pi * 2
            let r = radius * (1 + 0.09 * sin(a * 7 + CGFloat(seed)) + 0.05 * cos(a * 11))
            let p = CGPoint(x: cos(a) * r, y: sin(a) * r * 0.73)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        let node = SKShapeNode(path: path)
        node.fillColor = color
        node.strokeColor = .clear
        node.lineWidth = 0
        return node
    }

    static func nightTexture(size: CGSize, lights: [(CGPoint, CGFloat)]) -> SKTexture {
        let width = max(1, Int(size.width))
        let height = max(1, Int(size.height))
        let space = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: nil, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: width * 4, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            preconditionFailure("Cannot allocate the notebook lighting mask")
        }
        context.setFillColor(CGColor(red: 0.06, green: 0.09, blue: 0.17, alpha: 0.79))
        context.fill(CGRect(origin: .zero, size: size))
        let colors = [CGColor(gray: 0, alpha: 0.97), CGColor(gray: 0, alpha: 0.80),
                      CGColor(gray: 0, alpha: 0)] as CFArray
        let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 0.36, 1])!
        context.setBlendMode(.destinationOut)
        for (center, radius) in lights {
            context.drawRadialGradient(gradient, startCenter: center, startRadius: 0,
                                       endCenter: center, endRadius: radius, options: [])
        }
        return SKTexture(cgImage: context.makeImage()!)
    }

    static func eraser(size: CGFloat = 36) -> SKNode {
        let node = SKNode()
        let body = card(CGSize(width: size, height: size * 0.57),
                        fill: SKColor(red: 0.88, green: 0.56, blue: 0.49, alpha: 1), radius: 4)
        body.zRotation = -0.35
        node.addChild(body)
        let sleeve = card(CGSize(width: size * 0.44, height: size * 0.59),
                          fill: paper, radius: 2)
        sleeve.position.x = -size * 0.2
        body.addChild(sleeve)
        let stripe = rule(width: size * 0.3)
        sleeve.addChild(stripe)
        return node
    }

    static func tapFeedback() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        #endif
    }
}

/// Buttons are routed by the scene so an open modal cannot leak touches to the world.
final class NotebookButton: SKNode {
    let actionID: String
    let hitSize: CGSize
    let caption: SKLabelNode

    init(_ title: String, id: String, width: CGFloat, height: CGFloat = 46,
         filled: Bool = false, fontSize: CGFloat = 14) {
        actionID = id
        hitSize = CGSize(width: width, height: height)
        caption = NotebookVisuals.label(title, size: fontSize,
                                         color: filled ? NotebookVisuals.paper : NotebookVisuals.ink,
                                         sans: true)
        super.init()
        let face = NotebookVisuals.card(hitSize,
                                       fill: filled ? NotebookVisuals.ink : NotebookVisuals.paper,
                                       radius: 9)
        addChild(face)
        caption.zPosition = 1
        addChild(caption)
        name = id
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func hit(_ point: CGPoint, in node: SKNode) -> Bool {
        guard !isHidden, alpha > 0.1 else { return false }
        let local = convert(point, from: node)
        return CGRect(x: -hitSize.width / 2, y: -hitSize.height / 2,
                      width: hitSize.width, height: hitSize.height).contains(local)
    }
}
