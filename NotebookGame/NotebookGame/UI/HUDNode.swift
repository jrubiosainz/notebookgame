import SpriteKit

/// The status readout in the top-left corner: hearts, ink and coins, matching
/// the reference sketch the art direction is based on.
final class HUDNode: SKNode {

    private let heartsRow = SKNode()
    private let inkLabel = Paper.label("0", size: 20)
    private let coinLabel = Paper.label("0", size: 20)
    private let levelLabel = Paper.label("Lv 1", size: 17, color: Paper.softInk)

    private let heartSize: CGFloat = 26
    private let heartSpacing: CGFloat = 30
    /// Health per heart. Hearts are a readable stand-in for a raw number.
    private let hpPerHeart = 10
    private var heartNodes: [SKSpriteNode] = []

    override init() {
        super.init()
        zPosition = Layer.ui + 10

        addChild(heartsRow)

        let ink = SKSpriteNode(texture: Art.texture("ink_drop", in: "ui"))
        ink.size = CGSize(width: 22, height: 22)
        ink.position = CGPoint(x: 8, y: -38)
        addChild(ink)
        inkLabel.horizontalAlignmentMode = .left
        inkLabel.position = CGPoint(x: 26, y: -38)
        addChild(inkLabel)

        let coin = SKSpriteNode(texture: Art.texture("coin", in: "ui"))
        coin.size = CGSize(width: 22, height: 22)
        coin.position = CGPoint(x: 96, y: -38)
        addChild(coin)
        coinLabel.horizontalAlignmentMode = .left
        coinLabel.position = CGPoint(x: 114, y: -38)
        addChild(coinLabel)

        levelLabel.horizontalAlignmentMode = .left
        levelLabel.position = CGPoint(x: 8, y: -64)
        addChild(levelLabel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func refresh(from state: GameState) {
        let stats = state.totalStats
        let totalHearts = max(1, Int(ceil(Double(stats.maxHP) / Double(hpPerHeart))))
        rebuildHeartsIfNeeded(count: totalHearts)

        let filled = Int(ceil(Double(state.currentHP) / Double(hpPerHeart)))
        for (index, node) in heartNodes.enumerated() {
            let isFull = index < filled
            node.texture = Art.texture(isFull ? "heart_full" : "heart_empty", in: "ui")
        }

        inkLabel.text = "\(state.currentInk)/\(stats.maxInk)"
        coinLabel.text = "\(state.coins)"
        levelLabel.text = "Lv \(state.level)"
    }

    /// Flashes the hearts when the player takes a hit.
    func pulseDamage() {
        heartsRow.removeAllActions()
        heartsRow.run(.sequence([
            .scale(to: 1.18, duration: 0.08),
            .scale(to: 1.0, duration: 0.12)
        ]))
    }

    private func rebuildHeartsIfNeeded(count: Int) {
        guard count != heartNodes.count else { return }
        heartsRow.removeAllChildren()
        heartNodes = (0..<count).map { index in
            let heart = SKSpriteNode(texture: Art.texture("heart_full", in: "ui"))
            heart.size = CGSize(width: heartSize, height: heartSize)
            heart.position = CGPoint(x: 12 + CGFloat(index) * heartSpacing, y: 0)
            heartsRow.addChild(heart)
            return heart
        }
    }
}
