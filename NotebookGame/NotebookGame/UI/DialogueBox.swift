import SpriteKit

/// The bottom-of-screen text panel, with a typewriter reveal and tap-to-advance.
final class DialogueBox: SKNode {

    private let panel = SKSpriteNode(texture: Art.texture("dialogue_box", in: "ui"))
    private let text = SKLabelNode(fontNamed: Paper.handFont)
    private let prompt = Paper.label("tap", size: 15, color: Paper.softInk)

    private var lines: [String] = []
    private var lineIndex = 0
    private var revealed = 0
    private var revealTimer: Timer?
    private var completion: (() -> Void)?

    private let boxSize: CGSize

    private(set) var isPresenting = false

    init(width: CGFloat) {
        boxSize = CGSize(width: width, height: width * 0.30)
        super.init()

        panel.size = boxSize
        panel.zPosition = 0
        addChild(panel)

        text.fontSize = min(23, boxSize.width * 0.042)
        text.fontColor = Paper.ink
        text.numberOfLines = 3
        text.preferredMaxLayoutWidth = boxSize.width * 0.84
        text.horizontalAlignmentMode = .center
        text.verticalAlignmentMode = .center
        text.zPosition = 1
        addChild(text)

        prompt.position = CGPoint(x: boxSize.width * 0.40, y: -boxSize.height * 0.33)
        prompt.zPosition = 1
        addChild(prompt)

        zPosition = Layer.ui + 50
        alpha = 0
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    var height: CGFloat { boxSize.height }

    /// Shows a sequence of lines. `onFinish` fires after the last one is dismissed.
    func present(_ newLines: [String], onFinish: (() -> Void)? = nil) {
        guard !newLines.isEmpty else {
            onFinish?()
            return
        }
        lines = newLines
        lineIndex = 0
        completion = onFinish
        isPresenting = true
        isHidden = false
        removeAllActions()
        run(.fadeIn(withDuration: 0.14))
        startReveal()
    }

    /// Advances: completes the current line if still typing, otherwise moves on.
    /// Returns true while the box is still on screen.
    @discardableResult
    func advance() -> Bool {
        guard isPresenting else { return false }

        if revealed < currentLine.count {
            finishReveal()
            return true
        }

        lineIndex += 1
        if lineIndex >= lines.count {
            dismiss()
            return false
        }
        startReveal()
        return true
    }

    func dismiss() {
        stopTimer()
        isPresenting = false
        let done = completion
        completion = nil
        run(.sequence([
            .fadeOut(withDuration: 0.14),
            .run { [weak self] in
                self?.isHidden = true
                done?()
            }
        ]))
    }

    // MARK: - Typewriter

    private var currentLine: String {
        lineIndex < lines.count ? lines[lineIndex] : ""
    }

    private func startReveal() {
        stopTimer()
        revealed = 0
        text.text = ""
        prompt.alpha = 0

        let line = currentLine
        revealTimer = Timer.scheduledTimer(withTimeInterval: 0.024, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            self.revealed += 1
            if self.revealed >= line.count {
                self.finishReveal()
            } else {
                let end = line.index(line.startIndex, offsetBy: self.revealed)
                self.text.text = String(line[line.startIndex..<end])
            }
        }
        if let revealTimer {
            RunLoop.main.add(revealTimer, forMode: .common)
        }
    }

    private func finishReveal() {
        stopTimer()
        revealed = currentLine.count
        text.text = currentLine
        prompt.removeAllActions()
        prompt.alpha = 1
        prompt.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.25, duration: 0.5),
            .fadeAlpha(to: 1.0, duration: 0.5)
        ])))
    }

    private func stopTimer() {
        revealTimer?.invalidate()
        revealTimer = nil
    }

    deinit { revealTimer?.invalidate() }
}

/// A short message that floats up and fades, for pickups and level ups.
enum Toast {
    /// Attaches to the scene's camera when there is one, so the message stays
    /// put while the world scrolls underneath it.
    static func show(_ message: String, in scene: SKScene, at point: CGPoint? = nil) {
        let label = Paper.label(message, size: 24)
        label.zPosition = Layer.ui + 200
        label.setScale(0.7)
        label.alpha = 0  // otherwise the fadeIn below has nothing to fade from

        if let camera = scene.camera {
            label.position = point ?? CGPoint(x: 0, y: scene.size.height * 0.18)
            camera.addChild(label)
        } else {
            label.position = point ?? CGPoint(x: scene.size.width / 2, y: scene.size.height * 0.68)
            scene.addChild(label)
        }

        label.run(.sequence([
            .group([.scale(to: 1.0, duration: 0.18), .fadeIn(withDuration: 0.12)]),
            .wait(forDuration: 1.1),
            .group([.moveBy(x: 0, y: 40, duration: 0.4), .fadeOut(withDuration: 0.4)]),
            .removeFromParent()
        ]))
    }
}
