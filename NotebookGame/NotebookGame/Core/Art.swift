import SpriteKit
import UIKit

/// Loads and caches the generated artwork.
///
/// Every image in this game comes from `assets/`, which is added to the app
/// target as a folder reference so the on-disk layout is preserved inside the
/// bundle. That means the Python generator and the game agree on paths with no
/// manual bookkeeping: add an asset to `tools/manifest.py`, regenerate, and it
/// is immediately loadable here by the same key.
enum Art {
    private static var cache: [String: SKTexture] = [:]
    private static let lock = NSLock()

    /// A 1x1 transparent stand-in so a missing asset never crashes the game.
    private static let placeholder: SKTexture = {
        let size = CGSize(width: 2, height: 2)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor.clear.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        return SKTexture(image: image)
    }()

    /// Root of the bundled `assets/` folder reference.
    private static let assetsRoot: URL? = Bundle.main.resourceURL?.appendingPathComponent("assets")

    /// Loads `assets/<folder>/<name>.png`.
    static func texture(_ name: String, in folder: String) -> SKTexture {
        let key = "\(folder)/\(name)"

        lock.lock()
        if let hit = cache[key] {
            lock.unlock()
            return hit
        }
        lock.unlock()

        guard let root = assetsRoot,
              let image = UIImage(contentsOfFile:
                root.appendingPathComponent("\(key).png").path) else {
            assertionFailure("Missing art: assets/\(key).png. Run tools/generate_assets.py")
            return placeholder
        }

        let texture = SKTexture(image: image)
        texture.filteringMode = .linear

        lock.lock()
        cache[key] = texture
        lock.unlock()
        return texture
    }

    /// Loads the numbered frames a sheet was sliced into, in order.
    /// Falls back to a single static texture when a sheet is unavailable.
    static func frames(in folder: String, fallback: String, fallbackFolder: String) -> [SKTexture] {
        guard let root = assetsRoot else {
            return [texture(fallback, in: fallbackFolder)]
        }
        let dir = root.appendingPathComponent(folder)
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else {
            return [texture(fallback, in: fallbackFolder)]
        }

        let ordered = names
            .filter { $0.hasPrefix("frame_") && $0.hasSuffix(".png") }
            .sorted { frameIndex($0) < frameIndex($1) }

        let textures = ordered.compactMap { file -> SKTexture? in
            guard let image = UIImage(contentsOfFile: dir.appendingPathComponent(file).path) else {
                return nil
            }
            let t = SKTexture(image: image)
            t.filteringMode = .linear
            return t
        }

        return textures.isEmpty ? [texture(fallback, in: fallbackFolder)] : textures
    }

    private static func frameIndex(_ filename: String) -> Int {
        let digits = filename
            .replacingOccurrences(of: "frame_", with: "")
            .replacingOccurrences(of: ".png", with: "")
        return Int(digits) ?? 0
    }

    /// Preloads the art needed before the first frame so the map does not pop in.
    static func warmUp() {
        let essentials: [(String, String)] = [
            ("nib_idle", "characters"), ("nib_hurt", "characters"),
            ("paper", "tiles"), ("path", "tiles"), ("sand", "tiles"),
            ("water", "tiles"), ("stone", "tiles"),
            ("heart_full", "ui"), ("heart_empty", "ui"), ("ink_drop", "ui"),
            ("coin", "ui"), ("dialogue_box", "ui"),
            ("joystick_base", "ui"), ("joystick_knob", "ui")
        ]
        for (name, folder) in essentials {
            _ = texture(name, in: folder)
        }
    }
}

/// Sizes, fonts and colours shared by every scene, so the whole game keeps the
/// look of ink on a sheet of paper.
enum Paper {
    static let background = UIColor(white: 0.88, alpha: 1.0)
    static let ink = UIColor(white: 0.13, alpha: 1.0)
    static let softInk = UIColor(white: 0.42, alpha: 1.0)
    static let panel = UIColor(white: 0.96, alpha: 1.0)

    static let tileSize: CGFloat = 96

    /// Prefers a handwriting face, falling back gracefully across iOS versions.
    /// Resolved once: this is read every time a label is built.
    static let handFont: String = {
        let candidates = ["Chalkboard SE", "Noteworthy-Bold", "Bradley Hand", "MarkerFelt-Wide"]
        for name in candidates where UIFont(name: name, size: 12) != nil {
            return name
        }
        return "Helvetica-Bold"
    }()

    static func label(_ text: String, size: CGFloat, color: UIColor = Paper.ink) -> SKLabelNode {
        let node = SKLabelNode(fontNamed: handFont)
        node.text = text
        node.fontSize = size
        node.fontColor = color
        node.horizontalAlignmentMode = .center
        node.verticalAlignmentMode = .center
        return node
    }
}
