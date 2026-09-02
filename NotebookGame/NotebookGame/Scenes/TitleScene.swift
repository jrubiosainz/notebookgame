import SpriteKit

/// The cover of the notebook: logo, a couple of doodles, and a way in.
final class TitleScene: SKScene {

    private let state = GameState.shared

    override func didMove(to view: SKView) {
        backgroundColor = Paper.background
        scaleMode = .resizeFill
        Haptics.prepare()
        Art.warmUp()

        buildBackdrop()
        buildLogo()
        buildButtons()
    }

    private func buildBackdrop() {
        let backdrop = SKSpriteNode(texture: Art.texture("title_backdrop", in: "title"))
        let textureSize = backdrop.texture?.size() ?? size
        let scale = max(size.width / textureSize.width, size.height / textureSize.height)
        backdrop.size = CGSize(width: textureSize.width * scale,
                               height: textureSize.height * scale)
        backdrop.position = CGPoint(x: size.width / 2, y: size.height / 2)
        backdrop.zPosition = Layer.ground
        addChild(backdrop)
    }

    private func buildLogo() {
        let title = Paper.label("NOTEBOOK", size: min(72, size.width * 0.15))
        title.position = CGPoint(x: size.width / 2, y: size.height * 0.76)
        title.zPosition = Layer.ui
        addChild(title)

        let subtitle = Paper.label("QUEST", size: min(54, size.width * 0.11))
        subtitle.position = CGPoint(x: size.width / 2, y: size.height * 0.76 - title.frame.height)
        subtitle.zPosition = Layer.ui
        addChild(subtitle)

        // A slight, constant wobble sells the hand-drawn feel.
        for (index, node) in [title, subtitle].enumerated() {
            let delay = Double(index) * 0.4
            node.run(.sequence([
                .wait(forDuration: delay),
                .repeatForever(.sequence([
                    .rotate(toAngle: 0.018, duration: 1.6),
                    .rotate(toAngle: -0.018, duration: 1.6)
                ]))
            ]))
        }

        let hero = SKSpriteNode(texture: Art.texture("nib_idle", in: "characters"))
        let height = min(size.height * 0.22, 240)
        let ratio = hero.texture.map { $0.size().width / max(1, $0.size().height) } ?? 1
        hero.size = CGSize(width: height * ratio, height: height)
        hero.position = CGPoint(x: size.width / 2, y: size.height * 0.50)
        hero.zPosition = Layer.ui
        addChild(hero)
        hero.run(.repeatForever(.sequence([
            .moveBy(x: 0, y: 10, duration: 1.0),
            .moveBy(x: 0, y: -10, duration: 1.0)
        ])))
    }

    private func buildButtons() {
        let buttonSize = CGSize(width: min(size.width * 0.62, 340), height: 74)
        let hasSave = SaveSystem.hasSave

        var y = size.height * 0.30

        if hasSave {
            let resume = PaperButton(title: "CONTINUE", size: buttonSize, fontSize: 26) {
                [weak self] in
                self?.enterWorld()
            }
            resume.position = CGPoint(x: size.width / 2, y: y)
            resume.zPosition = Layer.ui
            addChild(resume)
            y -= buttonSize.height + 18
        }

        let newGame = PaperButton(title: hasSave ? "NEW PAGE" : "START",
                                  size: buttonSize,
                                  fontSize: 26) { [weak self] in
            self?.confirmNewGame(hasSave: hasSave)
        }
        newGame.position = CGPoint(x: size.width / 2, y: y)
        newGame.zPosition = Layer.ui
        addChild(newGame)

        if hasSave {
            let progress = Paper.label(
                "Lv \(state.level)  ·  \(MapCatalog.map(id: state.save.mapID).name)",
                size: 18, color: Paper.softInk)
            progress.position = CGPoint(x: size.width / 2, y: y - buttonSize.height * 0.9)
            progress.zPosition = Layer.ui
            addChild(progress)
        }
    }

    private func confirmNewGame(hasSave: Bool) {
        guard hasSave else {
            state.startNewGame()
            enterWorld()
            return
        }

        // Overwriting a save is the one destructive action in the game, so ask.
        let box = DialogueBox(width: min(size.width - 48, 640))
        box.position = CGPoint(x: size.width / 2, y: size.height * 0.16)
        addChild(box)

        let confirm = PaperButton(title: "ERASE & START",
                                  size: CGSize(width: 220, height: 62),
                                  fontSize: 20) { [weak self] in
            self?.state.startNewGame()
            self?.enterWorld()
        }
        confirm.position = CGPoint(x: size.width / 2 - 120, y: size.height * 0.32)
        confirm.zPosition = Layer.ui + 100
        addChild(confirm)

        let cancel = PaperButton(title: "KEEP",
                                 size: CGSize(width: 140, height: 62),
                                 fontSize: 20) { [weak self] in
            guard let self else { return }
            box.dismiss()
            confirm.removeFromParent()
            self.children.filter { $0.name == "cancelNewGame" }.forEach { $0.removeFromParent() }
        }
        cancel.name = "cancelNewGame"
        cancel.position = CGPoint(x: size.width / 2 + 120, y: size.height * 0.32)
        cancel.zPosition = Layer.ui + 100
        addChild(cancel)

        box.present(["This erases your current page. Start over?"])
    }

    private func enterWorld() {
        guard let view else { return }
        let overworld = OverworldScene(size: size)
        overworld.scaleMode = .resizeFill
        view.presentScene(overworld, transition: .fade(with: Paper.background, duration: 0.4))
    }
}
