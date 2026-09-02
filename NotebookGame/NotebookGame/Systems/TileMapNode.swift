import SpriteKit

/// Builds the visual world for a `MapDef` and answers movement questions about it.
///
/// Map data is authored top-down (row 0 is the northern edge) because that is
/// how it reads in source. SpriteKit's y axis points up, so this is the one
/// place that flip happens. Everything downstream works in tile coordinates.
final class TileMapNode: SKNode {

    let definition: MapDef
    private let tileSize = Paper.tileSize
    private var groundGrid: [[Ground]] = []
    private var propGrid: [[Prop]] = []

    /// Props are parented here so the overworld can depth-sort them with the player.
    let propLayer = SKNode()

    init(definition: MapDef) {
        self.definition = definition
        super.init()
        parseGrids()
        buildGround()
        buildProps()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    // MARK: - Geometry

    var widthInTiles: Int { definition.width }
    var heightInTiles: Int { definition.height }

    var worldSize: CGSize {
        CGSize(width: CGFloat(widthInTiles) * tileSize,
               height: CGFloat(heightInTiles) * tileSize)
    }

    /// Centre point of a tile, converting the top-down authoring grid to
    /// SpriteKit's bottom-up world.
    func position(ofTileX x: Int, y: Int) -> CGPoint {
        CGPoint(x: (CGFloat(x) + 0.5) * tileSize,
                y: (CGFloat(heightInTiles - 1 - y) + 0.5) * tileSize)
    }

    func tile(at point: CGPoint) -> (x: Int, y: Int) {
        let column = Int(floor(point.x / tileSize))
        let rowFromBottom = Int(floor(point.y / tileSize))
        return (column, heightInTiles - 1 - rowFromBottom)
    }

    func isInside(x: Int, y: Int) -> Bool {
        x >= 0 && y >= 0 && x < widthInTiles && y < heightInTiles
    }

    func ground(x: Int, y: Int) -> Ground? {
        guard isInside(x: x, y: y), x < groundGrid[y].count else { return nil }
        return groundGrid[y][x]
    }

    func prop(x: Int, y: Int) -> Prop {
        guard isInside(x: x, y: y), x < propGrid[y].count else { return .none }
        return propGrid[y][x]
    }

    func isWalkable(x: Int, y: Int) -> Bool {
        guard let g = ground(x: x, y: y) else { return false }
        return !g.blocksMovement && !prop(x: x, y: y).blocksMovement
    }

    /// True where wandering monsters should never appear.
    func isSafe(x: Int, y: Int) -> Bool {
        ground(x: x, y: y)?.isSafe ?? false
    }

    /// Can a body of the given radius stand centred on this point?
    /// Sampling the four corners of the body keeps the player from clipping
    /// diagonally into scenery.
    func canStand(at point: CGPoint, radius: CGFloat) -> Bool {
        let offsets: [CGPoint] = [
            CGPoint(x: -radius, y: -radius), CGPoint(x: radius, y: -radius),
            CGPoint(x: -radius, y: radius), CGPoint(x: radius, y: radius)
        ]
        for offset in offsets {
            let probe = CGPoint(x: point.x + offset.x, y: point.y + offset.y)
            let t = tile(at: probe)
            if !isWalkable(x: t.x, y: t.y) { return false }
        }
        return true
    }

    // MARK: - Construction

    private func parseGrids() {
        groundGrid = definition.groundRows.map { row in
            row.map { Ground(rawValue: $0) ?? .paper }
        }
        propGrid = definition.propRows.map { row in
            row.map { Prop(rawValue: $0) ?? .none }
        }
        // Defend against a short prop layer rather than crashing on device.
        while propGrid.count < groundGrid.count {
            propGrid.append(Array(repeating: .none, count: widthInTiles))
        }
    }

    private func buildGround() {
        // One sprite per tile. At 24x16 that is 384 nodes, which SpriteKit
        // batches into a single draw call because they all share one atlas.
        for (rowIndex, row) in groundGrid.enumerated() {
            for (columnIndex, ground) in row.enumerated() {
                let sprite = SKSpriteNode(texture: Art.texture(ground.textureName, in: "tiles"))
                sprite.size = CGSize(width: tileSize, height: tileSize)
                sprite.position = position(ofTileX: columnIndex, y: rowIndex)
                sprite.zPosition = Layer.ground
                addChild(sprite)
            }
        }
    }

    private func buildProps() {
        propLayer.zPosition = 1     // above the ground sprites, which sit at 0
        addChild(propLayer)

        for (rowIndex, row) in propGrid.enumerated() {
            for (columnIndex, prop) in row.enumerated() {
                guard let name = prop.textureName else { continue }
                let texture = Art.texture(name, in: "props")
                let sprite = SKSpriteNode(texture: texture)

                // Preserve the drawn aspect ratio; scale by height.
                let targetHeight = tileSize * prop.scale
                let ratio = texture.size().width / max(1, texture.size().height)
                sprite.size = CGSize(width: targetHeight * ratio, height: targetHeight)

                // Anchor at the base so tall props sit on their tile and can be
                // depth-sorted against the player.
                sprite.anchorPoint = CGPoint(x: 0.5, y: 0.12)
                sprite.position = position(ofTileX: columnIndex, y: rowIndex)
                sprite.zPosition = Layer.entity(y: sprite.position.y)
                propLayer.addChild(sprite)
            }
        }
    }
}

/// Central z-ordering policy. Entities are sorted by their world y so that
/// things lower on the screen draw in front, which sells the top-down view.
enum Layer {
    static let ground: CGFloat = 0
    static let overlay: CGFloat = 9_000
    static let ui: CGFloat = 10_000

    static func entity(y: CGFloat) -> CGFloat {
        // Higher on screen means further away, so a smaller z.
        max(1, 8_000 - y)
    }
}
