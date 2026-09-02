import SpriteKit

/// A single turn-based encounter. All the maths lives in `BattleEngine`; this
/// scene is presentation, input and pacing.
final class BattleScene: SKScene {

    // MARK: - Combat state

    private var hero: Combatant
    private var enemy: Combatant
    private let enemyDef: EnemyDef
    private let isBoss: Bool
    private let state = GameState.shared

    private enum Phase {
        case intro
        case awaitingCommand
        case resolving
        case finished
    }
    private var phase: Phase = .intro

    private enum Menu {
        case root, skills, items
    }
    private var menu: Menu = .root

    // MARK: - Nodes

    private let cameraNode = SKCameraNode()
    private var heroSprite: SKSpriteNode!
    private var enemySprite: SKSpriteNode!
    private var heroRestingTexture: SKTexture!
    private var heroAttackFrames: [SKTexture] = []
    private var heroBar: StatBar!
    private var enemyBar: StatBar!
    private var messageLabel: SKLabelNode!
    private var buttons: [PaperButton] = []
    private let buttonLayer = SKNode()

    // MARK: - Init

    init(size: CGSize, enemy definition: EnemyDef, isBoss: Bool) {
        self.enemyDef = definition
        self.enemy = definition.spawn()
        self.isBoss = isBoss
        self.hero = GameState.shared.makeHeroCombatant()
        super.init(size: size)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = Paper.background
        scaleMode = .resizeFill

        camera = cameraNode
        cameraNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(cameraNode)

        buildBackdrop()
        buildCombatants()
        buildInterface()
        playIntro()
    }

    // MARK: - Building

    private func buildBackdrop() {
        let backdrop = SKSpriteNode(texture: Art.texture("battle_backdrop", in: "ui"))
        // Fill the screen while preserving the drawn proportions.
        let textureSize = backdrop.texture?.size() ?? size
        let scale = max(size.width / textureSize.width, size.height / textureSize.height)
        backdrop.size = CGSize(width: textureSize.width * scale,
                               height: textureSize.height * scale)
        backdrop.position = CGPoint(x: size.width / 2, y: size.height / 2)
        backdrop.zPosition = Layer.ground
        backdrop.alpha = 0.85
        addChild(backdrop)
    }

    private func buildCombatants() {
        // Enemy: upper right, facing the player.
        let enemyTexture = Art.texture(enemy.spriteName, in: enemy.spriteFolder)
        enemySprite = SKSpriteNode(texture: enemyTexture)
        let enemyHeight = min(enemyDef.battleScale, size.height * 0.30)
        let enemyRatio = enemyTexture.size().width / max(1, enemyTexture.size().height)
        enemySprite.size = CGSize(width: enemyHeight * enemyRatio, height: enemyHeight)
        enemySprite.position = CGPoint(x: size.width * 0.66, y: size.height * 0.66)
        enemySprite.zPosition = Layer.entity(y: size.height * 0.66)
        addChild(enemySprite)

        // A slow float keeps the drawing feeling alive between turns.
        enemySprite.run(.repeatForever(.sequence([
            .moveBy(x: 0, y: 8, duration: 1.4),
            .moveBy(x: 0, y: -8, duration: 1.4)
        ])), withKey: "idle")

        // Hero: lower left, seen from behind - the first frame of the walk-up
        // cycle is exactly that pose, so there is no separate asset for it.
        let heroTexture = Art.frames(in: "characters/nib/walk_up",
                                     fallback: "nib_idle",
                                     fallbackFolder: "characters")[0]
        heroSprite = SKSpriteNode(texture: heroTexture)
        heroRestingTexture = heroTexture
        heroAttackFrames = Art.frames(in: "characters/nib/attack",
                                      fallback: "nib_idle",
                                      fallbackFolder: "characters")
        let heroHeight = min(size.height * 0.24, 220)
        let heroRatio = heroTexture.size().width / max(1, heroTexture.size().height)
        heroSprite.size = CGSize(width: heroHeight * heroRatio, height: heroHeight)
        heroSprite.position = CGPoint(x: size.width * 0.26, y: size.height * 0.40)
        heroSprite.zPosition = Layer.entity(y: size.height * 0.40)
        addChild(heroSprite)
    }

    private func buildInterface() {
        let inset: CGFloat = 24
        let safeTop = (view?.safeAreaInsets.top ?? 0)
        let safeBottom = (view?.safeAreaInsets.bottom ?? 0)
        let barWidth = min(size.width * 0.42, 320)

        enemyBar = StatBar(width: barWidth, title: enemy.name, showsInk: false)
        enemyBar.position = CGPoint(x: size.width - inset - barWidth / 2,
                                    y: size.height - safeTop - 44)
        enemyBar.zPosition = Layer.ui
        addChild(enemyBar)
        enemyBar.update(hp: enemy.currentHP, maxHP: enemy.stats.maxHP, ink: 0, maxInk: 0)

        heroBar = StatBar(width: barWidth, title: "Nib  Lv \(state.level)", showsInk: true)
        heroBar.position = CGPoint(x: inset + barWidth / 2,
                                   y: safeBottom + 236)
        heroBar.zPosition = Layer.ui
        addChild(heroBar)
        refreshHeroBar()

        messageLabel = SKLabelNode(fontNamed: Paper.handFont)
        messageLabel.fontSize = 22
        messageLabel.fontColor = Paper.ink
        messageLabel.numberOfLines = 2
        messageLabel.preferredMaxLayoutWidth = size.width - 80
        messageLabel.horizontalAlignmentMode = .center
        messageLabel.verticalAlignmentMode = .center
        messageLabel.position = CGPoint(x: size.width / 2, y: safeBottom + 190)
        messageLabel.zPosition = Layer.ui
        messageLabel.text = ""
        addChild(messageLabel)

        buttonLayer.zPosition = Layer.ui
        addChild(buttonLayer)
    }

    // MARK: - Command menu

    private func showRootMenu() {
        menu = .root
        layoutButtons([
            ("ATTACK", true, { [weak self] in self?.commit(.attack) }),
            ("SKILL", !state.skills.isEmpty, { [weak self] in self?.showSkillMenu() }),
            ("ITEM", !usableItems().isEmpty, { [weak self] in self?.showItemMenu() }),
            (isBoss ? "STAND" : "RUN", !isBoss, { [weak self] in self?.commit(.flee) })
        ])
    }

    private func showSkillMenu() {
        menu = .skills
        var entries: [(String, Bool, () -> Void)] = state.skills.map { skill in
            ("\(skill.name)  \(skill.inkCost)i",
             hero.currentInk >= skill.inkCost,
             { [weak self] in self?.commit(.skill(skill)) })
        }
        entries.append(("BACK", true, { [weak self] in self?.showRootMenu() }))
        layoutButtons(entries)
    }

    private func showItemMenu() {
        menu = .items
        var entries: [(String, Bool, () -> Void)] = usableItems().map { slot in
            let item = ItemCatalog.item(id: slot.itemID)
            let name = item?.name ?? slot.itemID
            return ("\(name) x\(slot.count)", true, { [weak self] in
                guard let self, let item else { return }
                _ = self.state.consumeItem(slot.itemID)
                self.commit(.item(item))
            })
        }
        entries.append(("BACK", true, { [weak self] in self?.showRootMenu() }))
        layoutButtons(entries)
    }

    private func usableItems() -> [InventorySlot] {
        state.inventory.filter { slot in
            guard let item = ItemCatalog.item(id: slot.itemID) else { return false }
            switch item.effect {
            case .restoreHP, .restoreInk, .cure: return true
            case .keyItem: return false
            }
        }
    }

    /// Lays out up to four commands in a 2x2 grid at the bottom of the screen.
    private func layoutButtons(_ entries: [(String, Bool, () -> Void)]) {
        buttonLayer.removeAllChildren()
        buttons.removeAll()

        let visible = Array(entries.prefix(6))
        let columns = 2
        let buttonSize = CGSize(width: min((size.width - 72) / 2, 300), height: 64)
        let spacingX: CGFloat = 16
        let spacingY: CGFloat = 12
        let rows = Int(ceil(Double(visible.count) / Double(columns)))
        let safeBottom = (view?.safeAreaInsets.bottom ?? 0)
        let originY = safeBottom + 40 + CGFloat(rows - 1) * (buttonSize.height + spacingY)

        for (index, entry) in visible.enumerated() {
            let row = index / columns
            let column = index % columns
            let totalWidth = CGFloat(columns) * buttonSize.width + CGFloat(columns - 1) * spacingX
            let x = size.width / 2 - totalWidth / 2 + buttonSize.width / 2
                + CGFloat(column) * (buttonSize.width + spacingX)
            let y = originY - CGFloat(row) * (buttonSize.height + spacingY)

            let button = PaperButton(title: entry.0, size: buttonSize, fontSize: 21, action: entry.2)
            button.position = CGPoint(x: x, y: y)
            button.setEnabled(entry.1)
            buttonLayer.addChild(button)
            buttons.append(button)
        }
    }

    private func clearButtons() {
        buttonLayer.removeAllChildren()
        buttons.removeAll()
    }

    // MARK: - Turn flow

    private func playIntro() {
        phase = .intro
        clearButtons()
        say(isBoss ? "\(enemy.name) blocks the last page!" : "A \(enemy.name) appears!")

        enemySprite.setScale(0.2)
        enemySprite.alpha = 0
        enemySprite.run(.group([
            .fadeIn(withDuration: 0.25),
            .sequence([.scale(to: 1.12, duration: 0.28), .scale(to: 1.0, duration: 0.14)])
        ])) { [weak self] in
            self?.beginPlayerTurn()
        }
    }

    private func beginPlayerTurn() {
        guard phase != .finished else { return }
        phase = .awaitingCommand
        showRootMenu()
    }

    private func commit(_ action: BattleEngine.Action) {
        guard phase == .awaitingCommand else { return }
        phase = .resolving
        clearButtons()

        let heroFirst = BattleEngine.heroActsFirst(hero: hero, enemy: enemy)
        if heroFirst {
            runHeroAction(action) { [weak self] in
                self?.runEnemyTurnIfAlive { self?.endRound() }
            }
        } else {
            runEnemyTurnIfAlive { [weak self] in
                guard let self, self.phase != .finished else { return }
                self.runHeroAction(action) { self.endRound() }
            }
        }
    }

    private func runHeroAction(_ action: BattleEngine.Action, then next: @escaping () -> Void) {
        let events = BattleEngine.resolveHero(action: action, hero: &hero, enemy: &enemy)
        animateHeroLunge(for: action)
        play(events: events, completion: next)
    }

    private func runEnemyTurnIfAlive(_ next: @escaping () -> Void) {
        guard phase != .finished, !enemy.isDown else {
            next()
            return
        }
        let events = BattleEngine.resolveEnemy(hero: &hero, enemy: &enemy)
        animateEnemyLunge()
        play(events: events, completion: next)
    }

    private func endRound() {
        guard phase != .finished else { return }
        refreshHeroBar()
        enemyBar.update(hp: enemy.currentHP, maxHP: enemy.stats.maxHP, ink: 0, maxInk: 0)
        beginPlayerTurn()
    }

    /// Narrates a list of events one after another, animating each.
    private func play(events: [BattleEngine.Event], completion: @escaping () -> Void) {
        guard !events.isEmpty else {
            completion()
            return
        }

        var queue = events
        let event = queue.removeFirst()
        say(event.message)
        react(to: event)

        refreshHeroBar()
        enemyBar.update(hp: enemy.currentHP, maxHP: enemy.stats.maxHP, ink: 0, maxInk: 0)

        // Terminal events take over the flow entirely.
        switch event.kind {
        case .enemyDefeated:
            finishWithVictory()
            return
        case .heroDefeated:
            finishWithDefeat()
            return
        case .fleeSucceeded:
            finishWithEscape()
            return
        default:
            break
        }

        run(.wait(forDuration: 0.85)) { [weak self] in
            self?.play(events: queue, completion: completion)
        }
    }

    private func react(to event: BattleEngine.Event) {
        switch event.kind {
        case .heroAttack(let damage, let critical):
            landHeroHit(damage: damage, critical: critical)

        case .heroSkill(_, let damage, let healed):
            if damage > 0 {
                landHeroHit(damage: damage, critical: false)
            }
            if healed > 0 {
                showDamage(healed, at: heroSprite.position, critical: false, healing: true)
                Haptics.success()
            }

        case .enemyAttack(let damage, let critical):
            showDamage(damage, at: heroSprite.position, critical: critical)
            flash(heroSprite)
            impact(at: heroSprite.position)
            shakeCamera(intensity: critical ? 14 : 7)
            Haptics.bigHit()

        case .heroItem, .notEnoughInk, .fleeFailed, .fleeSucceeded:
            Haptics.tap()

        case .enemyDefeated:
            enemySprite.removeAction(forKey: "idle")
            enemySprite.run(.group([
                .fadeOut(withDuration: 0.5),
                .scale(to: 0.7, duration: 0.5),
                .rotate(byAngle: 0.4, duration: 0.5)
            ]))

        case .heroDefeated:
            heroSprite.run(.group([
                .fadeAlpha(to: 0.25, duration: 0.4),
                .rotate(byAngle: -0.5, duration: 0.4)
            ]))
        }
    }

    private func landHeroHit(damage: Int, critical: Bool) {
        swingPencil()
        showDamage(damage, at: enemySprite.position, critical: critical)
        flash(enemySprite)
        slash(at: enemySprite.position)
        if critical { shakeCamera(intensity: 10) }
        Haptics.hit()
    }

    /// Plays the pencil-swing sheet, then settles back into the resting
    /// back-view pose. Movement is handled separately by `animateHeroLunge`.
    private func swingPencil() {
        guard heroAttackFrames.count > 1 else { return }
        heroSprite.removeAction(forKey: "swing")

        // resize: false keeps the sprite's on-screen footprint stable even
        // though the side-profile frames have a different aspect ratio.
        heroSprite.run(.sequence([
            .animate(with: heroAttackFrames, timePerFrame: 0.07, resize: false, restore: false),
            .wait(forDuration: 0.08),
            .setTexture(heroRestingTexture)
        ]), withKey: "swing")
    }

    // MARK: - Endings

    private func finishWithVictory() {
        phase = .finished
        clearButtons()
        state.syncFromBattle(hp: hero.currentHP, ink: hero.currentInk)

        let loot = enemy.lootTable.filter { _ in Double.random(in: 0...1) < 0.45 }
        let levelled = state.award(experience: enemy.experienceReward,
                                   coins: enemy.coinReward,
                                   loot: loot)

        if isBoss { state.set(flag: "beat_big_smudge") }

        var lines = ["You won! +\(enemy.experienceReward) XP, +\(enemy.coinReward) coins."]
        if !loot.isEmpty {
            let names = loot.compactMap { ItemCatalog.item(id: $0)?.name }
            lines.append("Found: " + names.joined(separator: ", "))
        }
        if levelled {
            lines.append("Level \(state.level)! You feel more confident.")
        }
        if isBoss {
            lines.append("The page is clean again. The doodles are safe.")
        }

        Haptics.success()
        showEndingBanner(lines: lines) { [weak self] in
            self?.returnToOverworld()
        }
    }

    private func finishWithDefeat() {
        phase = .finished
        clearButtons()
        Haptics.failure()
        showEndingBanner(lines: [
            "Your outline fades...",
            "You wake up back at camp, a few coins lighter."
        ]) { [weak self] in
            self?.state.reviveAtCamp()
            self?.returnToOverworld()
        }
    }

    private func finishWithEscape() {
        phase = .finished
        clearButtons()
        state.syncFromBattle(hp: hero.currentHP, ink: hero.currentInk)
        state.persist()
        run(.wait(forDuration: 0.7)) { [weak self] in
            self?.returnToOverworld()
        }
    }

    private func showEndingBanner(lines: [String], then: @escaping () -> Void) {
        let box = DialogueBox(width: min(size.width - 48, 720))
        box.position = CGPoint(x: size.width / 2,
                               y: (view?.safeAreaInsets.bottom ?? 0) + box.height / 2 + 30)
        addChild(box)
        box.present(lines, onFinish: then)
    }

    private func returnToOverworld() {
        guard let view else { return }
        state.persist()
        let overworld = OverworldScene(size: size)
        overworld.scaleMode = .resizeFill
        view.presentScene(overworld, transition: .fade(with: Paper.background, duration: 0.35))
    }

    // MARK: - Presentation helpers

    private func say(_ message: String) {
        messageLabel.text = message
        messageLabel.setScale(0.94)
        messageLabel.run(.scale(to: 1.0, duration: 0.12))
    }

    private func refreshHeroBar() {
        heroBar.update(hp: hero.currentHP, maxHP: hero.stats.maxHP,
                       ink: hero.currentInk, maxInk: hero.stats.maxInk)
    }

    private func animateHeroLunge(for action: BattleEngine.Action) {
        switch action {
        case .attack, .skill:
            let origin = heroSprite.position
            heroSprite.run(.sequence([
                .move(to: CGPoint(x: origin.x + 46, y: origin.y + 22), duration: 0.10),
                .move(to: origin, duration: 0.16)
            ]))
        case .item, .flee:
            heroSprite.run(.sequence([
                .scaleY(to: 0.92, duration: 0.09),
                .scaleY(to: 1.0, duration: 0.12)
            ]))
        }
    }

    private func animateEnemyLunge() {
        let origin = enemySprite.position
        enemySprite.run(.sequence([
            .move(to: CGPoint(x: origin.x - 42, y: origin.y - 20), duration: 0.10),
            .move(to: origin, duration: 0.16)
        ]))
    }

    private func flash(_ node: SKSpriteNode) {
        node.run(.sequence([
            .fadeAlpha(to: 0.25, duration: 0.06),
            .fadeAlpha(to: 1.0, duration: 0.08),
            .fadeAlpha(to: 0.4, duration: 0.06),
            .fadeAlpha(to: 1.0, duration: 0.08)
        ]))
    }

    private func slash(at point: CGPoint) {
        let fx = SKSpriteNode(texture: Art.texture("slash_fx", in: "ui"))
        fx.size = CGSize(width: 190, height: 190)
        fx.position = point
        fx.zPosition = Layer.ui - 1
        fx.zRotation = CGFloat.random(in: -0.4...0.4)
        fx.setScale(0.6)
        addChild(fx)
        fx.run(.sequence([
            .group([.scale(to: 1.15, duration: 0.16), .fadeOut(withDuration: 0.26)]),
            .removeFromParent()
        ]))
    }

    private func impact(at point: CGPoint) {
        let fx = SKSpriteNode(texture: Art.texture("impact_fx", in: "ui"))
        fx.size = CGSize(width: 170, height: 170)
        fx.position = CGPoint(x: point.x + CGFloat.random(in: -18...18),
                              y: point.y + CGFloat.random(in: -10...30))
        fx.zPosition = Layer.ui - 1
        fx.zRotation = CGFloat.random(in: -0.5...0.5)
        fx.setScale(0.45)
        addChild(fx)
        fx.run(.sequence([
            .scale(to: 1.05, duration: 0.10),
            .group([.scale(to: 0.9, duration: 0.18), .fadeOut(withDuration: 0.18)]),
            .removeFromParent()
        ]))
    }

    private func showDamage(_ amount: Int, at point: CGPoint, critical: Bool, healing: Bool = false) {
        let text: String
        if healing {
            text = "+\(amount)"
        } else {
            text = critical ? "\(amount)!" : "\(amount)"
        }
        let label = Paper.label(text, size: critical ? 44 : 34)
        label.position = CGPoint(x: point.x + CGFloat.random(in: -22...22), y: point.y)
        label.zPosition = Layer.ui + 120
        addChild(label)
        label.run(.sequence([
            .group([.moveBy(x: 0, y: 74, duration: 0.6),
                    .sequence([.wait(forDuration: 0.3), .fadeOut(withDuration: 0.3)])]),
            .removeFromParent()
        ]))
    }

    private func shakeCamera(intensity: CGFloat) {
        let origin = CGPoint(x: size.width / 2, y: size.height / 2)
        var steps: [SKAction] = []
        for _ in 0..<5 {
            steps.append(.move(to: CGPoint(x: origin.x + .random(in: -intensity...intensity),
                                           y: origin.y + .random(in: -intensity...intensity)),
                               duration: 0.035))
        }
        steps.append(.move(to: origin, duration: 0.05))
        cameraNode.run(.sequence(steps))
    }

    // MARK: - Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard phase == .finished else { return }
        // Advance the victory/defeat text.
        for child in children {
            if let box = child as? DialogueBox, box.isPresenting {
                box.advance()
                return
            }
        }
    }
}

/// A labelled health (and optionally ink) gauge drawn in the notebook style.
final class StatBar: SKNode {

    private let barWidth: CGFloat
    private let title: SKLabelNode
    private let hpTrack = SKShapeNode()
    private let hpFill = SKShapeNode()
    private let inkTrack = SKShapeNode()
    private let inkFill = SKShapeNode()
    private let readout: SKLabelNode
    private let showsInk: Bool
    private let barHeight: CGFloat = 14

    init(width: CGFloat, title name: String, showsInk: Bool) {
        self.barWidth = width
        self.showsInk = showsInk
        self.title = Paper.label(name, size: 19)
        self.readout = Paper.label("", size: 15, color: Paper.softInk)
        super.init()

        let backing = SKShapeNode(rectOf: CGSize(width: width + 22,
                                                 height: showsInk ? 92 : 66),
                                  cornerRadius: 12)
        backing.fillColor = Paper.background.withAlphaComponent(0.86)
        backing.strokeColor = Paper.ink
        backing.lineWidth = 2.5
        backing.zPosition = 0
        addChild(backing)

        title.horizontalAlignmentMode = .left
        title.position = CGPoint(x: -width / 2, y: showsInk ? 26 : 14)
        title.zPosition = 1
        addChild(title)

        configure(track: hpTrack, fill: hpFill,
                  y: showsInk ? 2 : -10, fillColor: Paper.ink)
        if showsInk {
            configure(track: inkTrack, fill: inkFill, y: -24,
                      fillColor: Paper.softInk)
        }

        readout.horizontalAlignmentMode = .right
        readout.position = CGPoint(x: width / 2, y: showsInk ? 26 : 14)
        readout.zPosition = 1
        addChild(readout)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    private func configure(track: SKShapeNode, fill: SKShapeNode, y: CGFloat, fillColor: UIColor) {
        let rect = CGRect(x: -barWidth / 2, y: y, width: barWidth, height: barHeight)
        track.path = CGPath(roundedRect: rect, cornerWidth: 6, cornerHeight: 6, transform: nil)
        track.fillColor = .clear
        track.strokeColor = Paper.ink
        track.lineWidth = 2
        track.zPosition = 1
        addChild(track)

        fill.fillColor = fillColor
        fill.strokeColor = .clear
        fill.zPosition = 2
        addChild(fill)
    }

    func update(hp: Int, maxHP: Int, ink: Int, maxInk: Int) {
        setFill(hpFill, fraction: maxHP > 0 ? CGFloat(hp) / CGFloat(maxHP) : 0,
                y: showsInk ? 2 : -10)
        if showsInk {
            setFill(inkFill, fraction: maxInk > 0 ? CGFloat(ink) / CGFloat(maxInk) : 0, y: -24)
            readout.text = "\(max(0, hp))/\(maxHP)   \(max(0, ink)) ink"
        } else {
            readout.text = "\(max(0, hp))/\(maxHP)"
        }
    }

    private func setFill(_ node: SKShapeNode, fraction: CGFloat, y: CGFloat) {
        let clamped = max(0, min(1, fraction))
        guard clamped > 0.001 else {
            node.path = nil
            return
        }
        let inset: CGFloat = 3
        let width = (barWidth - inset * 2) * clamped
        let rect = CGRect(x: -barWidth / 2 + inset, y: y + inset,
                          width: width, height: barHeight - inset * 2)
        node.path = CGPath(roundedRect: rect, cornerWidth: 4, cornerHeight: 4, transform: nil)
    }
}
