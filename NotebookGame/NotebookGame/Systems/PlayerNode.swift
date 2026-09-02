import SpriteKit

/// The hero on the overworld: sprite, facing, and walk animation.
final class PlayerNode: SKNode {

    enum Facing {
        case down, up, left, right
    }

    private let sprite = SKSpriteNode()
    private(set) var facing: Facing = .down
    private var isWalking = false

    /// Collision radius in points. Comfortably smaller than a tile so corners
    /// are forgiving.
    let bodyRadius: CGFloat = Paper.tileSize * 0.22

    private lazy var walkDown = Art.frames(in: "characters/nib/walk_down",
                                           fallback: "nib_idle", fallbackFolder: "characters")
    private lazy var walkUp = Art.frames(in: "characters/nib/walk_up",
                                         fallback: "nib_idle", fallbackFolder: "characters")
    private lazy var walkSide = Art.frames(in: "characters/nib/walk_side",
                                           fallback: "nib_idle", fallbackFolder: "characters")
    private let idleTexture = Art.texture("nib_idle", in: "characters")

    override init() {
        super.init()

        let height = Paper.tileSize * 1.35
        let ratio = idleTexture.size().width / max(1, idleTexture.size().height)
        sprite.texture = idleTexture
        sprite.size = CGSize(width: height * ratio, height: height)
        // Feet at the node origin, so map position and depth sorting agree.
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.05)
        addChild(sprite)

        addShadow()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    private func addShadow() {
        let shadow = SKShapeNode(ellipseOf: CGSize(width: Paper.tileSize * 0.5,
                                                   height: Paper.tileSize * 0.18))
        shadow.fillColor = UIColor(white: 0.35, alpha: 0.22)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: 4)
        shadow.zPosition = -1
        addChild(shadow)
    }

    /// Points the hero in the direction of travel and animates accordingly.
    func update(direction: CGVector) {
        let moving = abs(direction.dx) > 0.01 || abs(direction.dy) > 0.01

        if moving {
            let newFacing: Facing
            if abs(direction.dx) > abs(direction.dy) {
                newFacing = direction.dx > 0 ? .right : .left
            } else {
                newFacing = direction.dy > 0 ? .up : .down
            }
            if newFacing != facing || !isWalking {
                facing = newFacing
                startWalking()
            }
        } else if isWalking {
            stopWalking()
        }
    }

    private func startWalking() {
        isWalking = true
        sprite.removeAction(forKey: "walk")

        let frames: [SKTexture]
        switch facing {
        case .down: frames = walkDown
        case .up: frames = walkUp
        case .left, .right: frames = walkSide
        }

        // The side sheet is drawn facing right; mirror it for the other way.
        sprite.xScale = (facing == .left) ? -1 : 1

        guard frames.count > 1 else {
            sprite.texture = frames.first ?? idleTexture
            return
        }
        sprite.run(.repeatForever(.animate(with: frames,
                                           timePerFrame: 0.12,
                                           resize: false,
                                           restore: false)), withKey: "walk")
    }

    private func stopWalking() {
        isWalking = false
        sprite.removeAction(forKey: "walk")
        sprite.xScale = 1
        sprite.texture = idleTexture
    }

    /// A quick squash used when the player bumps into scenery.
    func nudge() {
        guard action(forKey: "nudge") == nil else { return }
        run(.sequence([
            .scaleX(to: 1.08, y: 0.94, duration: 0.06),
            .scaleX(to: 1.0, y: 1.0, duration: 0.08)
        ]), withKey: "nudge")
    }
}
