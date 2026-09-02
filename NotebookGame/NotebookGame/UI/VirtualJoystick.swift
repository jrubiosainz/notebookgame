import SpriteKit

/// A thumb stick drawn in the same ink as the world.
///
/// It is "floating": the base re-centres wherever the player first touches
/// inside its active area, which is far more forgiving on a phone than a fixed
/// pad.
final class VirtualJoystick: SKNode {

    private let base = SKSpriteNode(texture: Art.texture("joystick_base", in: "ui"))
    private let knob = SKSpriteNode(texture: Art.texture("joystick_knob", in: "ui"))
    private let radius: CGFloat
    private var activeTouch: UITouch?
    private var homePosition: CGPoint = .zero

    /// Normalised direction, magnitude 0...1. Zero when untouched.
    private(set) var vector: CGVector = .zero

    var isActive: Bool { activeTouch != nil }

    init(radius: CGFloat = 76) {
        self.radius = radius
        super.init()

        base.size = CGSize(width: radius * 2, height: radius * 2)
        base.alpha = 0.35
        base.zPosition = Layer.ui
        addChild(base)

        knob.size = CGSize(width: radius * 0.78, height: radius * 0.78)
        knob.alpha = 0.6
        knob.zPosition = Layer.ui + 1
        addChild(knob)

        isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func place(at point: CGPoint) {
        homePosition = point
        position = point
    }

    // MARK: - Touch routing (driven by the scene)

    /// Returns true when this joystick claimed the touch.
    func begin(touch: UITouch, at location: CGPoint) -> Bool {
        guard activeTouch == nil else { return false }
        activeTouch = touch
        // Re-centre under the thumb so the first movement is not a jump.
        position = location
        knob.position = .zero
        vector = .zero
        run(.fadeAlpha(to: 1.0, duration: 0.08))
        return true
    }

    func move(touch: UITouch, to location: CGPoint) {
        guard touch === activeTouch else { return }
        let dx = location.x - position.x
        let dy = location.y - position.y
        let distance = sqrt(dx * dx + dy * dy)

        if distance <= radius {
            knob.position = CGPoint(x: dx, y: dy)
        } else {
            let scale = radius / max(distance, 0.001)
            knob.position = CGPoint(x: dx * scale, y: dy * scale)
        }

        let magnitude = min(distance / radius, 1.0)
        if magnitude < 0.16 {
            vector = .zero          // dead zone, stops jitter when resting
        } else {
            let inverse = 1.0 / max(distance, 0.001)
            vector = CGVector(dx: dx * inverse * magnitude, dy: dy * inverse * magnitude)
        }
    }

    func end(touch: UITouch) {
        guard touch === activeTouch else { return }
        activeTouch = nil
        vector = .zero
        knob.run(.move(to: .zero, duration: 0.12))
        position = homePosition
        run(.fadeAlpha(to: 0.55, duration: 0.18))
    }

    func reset() {
        activeTouch = nil
        vector = .zero
        knob.position = .zero
        position = homePosition
    }
}

/// A rounded, hand-drawn button with a label.
final class PaperButton: SKNode {

    private let background: SKSpriteNode
    private let label: SKLabelNode
    private let action: () -> Void
    private(set) var isEnabled: Bool = true

    var size: CGSize { background.size }

    init(title: String, size: CGSize, fontSize: CGFloat = 22,
         showsBackground: Bool = true, action: @escaping () -> Void) {
        self.action = action
        background = SKSpriteNode(texture: Art.texture("button", in: "ui"))
        background.size = size
        // A list row is far wider than the drawing's 1.6:1 shape, and stretching
        // it that far leaves the text nowhere clean to sit. Such rows keep the
        // sprite purely as a hit area and draw their own rule instead.
        background.alpha = showsBackground ? 1.0 : 0.0
        label = Paper.label(title, size: fontSize)

        super.init()

        background.zPosition = 0
        addChild(background)
        label.zPosition = 1
        label.verticalAlignmentMode = .center
        // The button is drawn in perspective: the flat readable face sits a
        // little above the sprite's own centre, with the extruded edge below.
        label.position = CGPoint(x: 0, y: showsBackground ? size.height * PaperButton.faceOffset : 0)
        addChild(label)

        isUserInteractionEnabled = true
    }

    /// Distance from the sprite centre up to the centre of the paper face,
    /// measured from the generated artwork as a fraction of its height. A label
    /// box of 0.70w x 0.24h at this offset lands on 100% blank paper.
    static let faceOffset: CGFloat = 0.08

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    var title: String {
        get { label.text ?? "" }
        set { label.text = newValue }
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        alpha = enabled ? 1.0 : 0.35
    }

    func contains(scenePoint: CGPoint) -> Bool {
        guard let scene else { return false }
        return background.frame.contains(convert(scenePoint, from: scene))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isEnabled else { return }
        run(.scale(to: 0.94, duration: 0.05))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isEnabled else { return }
        run(.scale(to: 1.0, duration: 0.08))
        guard let touch = touches.first else { return }
        if background.frame.contains(touch.location(in: self)) {
            Haptics.tap()
            action()
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        run(.scale(to: 1.0, duration: 0.08))
    }
}
