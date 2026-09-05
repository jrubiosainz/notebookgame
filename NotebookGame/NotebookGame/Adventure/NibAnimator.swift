import SpriteKit

/// All poses use the same directional sheets, including the resting pose.
/// Distance drives the gait; simulation time drives gestures, so both pause with the game.
final class NibAnimator: SKNode {
    enum Facing: CaseIterable {
        case down, up, left, right

        init(direction: CGVector) {
            if abs(direction.dx) > abs(direction.dy) {
                self = direction.dx < 0 ? .left : .right
            } else {
                self = direction.dy > 0 ? .up : .down
            }
        }

        var direction: CGVector {
            switch self {
            case .down: return CGVector(dx: 0, dy: -1)
            case .up: return CGVector(dx: 0, dy: 1)
            case .left: return CGVector(dx: -1, dy: 0)
            case .right: return CGVector(dx: 1, dy: 0)
            }
        }

        var sheet: String {
            switch self {
            case .down: return "characters/nib/walk_down"
            case .up: return "characters/nib/walk_up"
            case .left, .right: return "characters/nib/walk_side"
            }
        }
    }

    enum Gesture: Equatable {
        case erase
        case paint(Pigment)

        var duration: Double {
            switch self {
            case .erase: return 0.32
            case .paint: return 0.46
            }
        }
    }

    private struct Clip {
        let frames: [SKTexture]
        let scale: CGFloat
    }

    private let body = SKSpriteNode()
    private let heldTool = SKNode()
    private let clips: [String: Clip]
    private let poseScale: CGFloat
    private var stridePhase = 0.0
    private var restTime = 0.0
    private var gestureTime = 0.0
    private(set) var facing: Facing = .down
    private(set) var frameIndex = 1
    private(set) var isWalking = false
    private(set) var gesture: Gesture?

    var isHoldingTool: Bool { !heldTool.isHidden && !heldTool.children.isEmpty }

    init(height: CGFloat = 76) {
        var loaded: [String: Clip] = [:]
        for folder in ["characters/nib/walk_down", "characters/nib/walk_up", "characters/nib/walk_side"] {
            let frames = (0..<4).map { NotebookVisuals.texture("frame_\($0)", folder: folder) }
            let maxHeight = frames.map { $0.size().height }.max() ?? 1
            loaded[folder] = Clip(frames: frames, scale: height / max(1, maxHeight))
        }
        clips = loaded
        poseScale = height / 76
        super.init()
        name = "nib"
        body.name = "nib-body"
        body.anchorPoint = CGPoint(x: 0.5, y: 0)
        addChild(body)
        heldTool.name = "nib-held-tool"
        heldTool.setScale(poseScale)
        heldTool.isHidden = true
        addChild(heldTool)
        let shadow = NotebookVisuals.wash(radius: 17 * poseScale, color: NotebookVisuals.ink.withAlphaComponent(0.15))
        shadow.zPosition = -2
        addChild(shadow)
        showFrame(1)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func reset(facing: Facing) {
        self.facing = facing
        isWalking = false
        stridePhase = 0
        restTime = 0
        finishGesture()
        showFrame(1)
        pose()
    }

    func update(dt: Double, displacement: CGVector, heading: CGVector) {
        guard dt.isFinite, dt > 0 else { return }
        let distance = hypot(displacement.dx, displacement.dy)
        isWalking = distance > 0.00001
        if isWalking {
            if gesture == nil { facing = Facing(direction: heading) }
            // A full four-frame stride spans 1.36 tiles at every joystick speed.
            stridePhase = (stridePhase + Double(distance) / 0.34).truncatingRemainder(dividingBy: 4)
            restTime = 0
        } else {
            stridePhase = 0
            restTime += dt
        }
        if let gesture {
            gestureTime += dt
            if gestureTime >= gesture.duration {
                finishGesture()
                if isWalking { facing = Facing(direction: heading) }
            }
        }
        pose()
    }

    func play(_ gesture: Gesture, toward direction: CGVector) {
        if hypot(direction.dx, direction.dy) > 0.001 {
            facing = Facing(direction: direction)
        }
        self.gesture = gesture
        gestureTime = 0
        heldTool.removeAllChildren()
        switch gesture {
        case .erase:
            heldTool.addChild(NotebookVisuals.eraser(size: 13))
        case .paint(let pigment):
            let handle = SKShapeNode(rectOf: CGSize(width: 3, height: 16), cornerRadius: 1)
            handle.fillColor = NotebookVisuals.paper
            handle.strokeColor = NotebookVisuals.ink
            handle.lineWidth = 1
            handle.position.y = 4
            heldTool.addChild(handle)
            let bristles = SKShapeNode(ellipseOf: CGSize(width: 6, height: 9))
            bristles.fillColor = NotebookVisuals.color(pigment)
            bristles.strokeColor = NotebookVisuals.ink
            bristles.lineWidth = 0.7
            bristles.position.y = 16
            heldTool.addChild(bristles)
        }
        pose()
    }

    private func finishGesture() {
        gesture = nil
        gestureTime = 0
        heldTool.removeAllChildren()
        heldTool.isHidden = true
    }

    private func showFrame(_ index: Int) {
        guard let clip = clips[facing.sheet] else {
            preconditionFailure("Missing directional clip for Nib")
        }
        frameIndex = index
        let texture = clip.frames[index]
        body.texture = texture
        body.size = CGSize(width: texture.size().width * clip.scale,
                           height: texture.size().height * clip.scale)
        body.xScale = facing == .left ? -1 : 1
    }

    private func pose() {
        body.position = .zero
        body.yScale = 1
        body.zRotation = 0
        guard let gesture else {
            showFrame(isWalking ? Int(stridePhase + 0.0000001) % 4 : 1)
            body.position.y = isWalking ? 0 : sin(restTime * 2) * 0.45 * poseScale
            return
        }
        let progress = min(1, gestureTime / gesture.duration)
        let sweep = CGFloat(sin(progress * .pi))
        let release = CGFloat(sin(max(0, progress - 0.20) / 0.80 * .pi))
        let poses = [1, 0, 2, 3, 1]
        showFrame(poses[min(4, Int(progress * 5))])
        let direction = facing.direction
        body.position = CGPoint(x: direction.dx * sweep * 3 * poseScale,
                                y: (direction.dy * sweep * 2 - sweep * 1.2) * poseScale)
        body.zRotation = -direction.dx * sweep * 0.09
        body.yScale = 1 - sweep * 0.035
        let handX: CGFloat
        switch facing {
        case .left: handX = -9
        case .right: handX = 9
        case .down: handX = -11
        case .up: handX = 11
        }
        let strokeCount = gesture == .erase ? 4.0 : 2.0
        let brushArc = CGFloat(sin(progress * .pi * strokeCount)) * 3
        heldTool.position = CGPoint(x: (handX + direction.dx * release * 6 + brushArc) * poseScale,
                                    y: (28 + direction.dy * release * 5) * poseScale)
        heldTool.zRotation = atan2(-direction.dx, direction.dy) + brushArc * 0.12
        heldTool.zPosition = facing == .up ? -1 : 1
        heldTool.isHidden = progress < 0.12 || progress > 0.86
    }
}
