import SpriteKit

/// Walking around the world: movement, scenery, NPCs, chests, exits and the
/// random encounters that lead into `BattleScene`.
final class OverworldScene: SKScene {

    // MARK: - Configuration

    private let walkSpeed: CGFloat = 250        // points per second
    private let interactionRange: CGFloat = Paper.tileSize * 1.3

    // MARK: - World

    private var mapNode: TileMapNode!
    private let worldNode = SKNode()
    private let player = PlayerNode()
    private let cameraNode = SKCameraNode()

    private var npcNodes: [(def: NPCDef, node: SKNode)] = []
    private var chestNodes: [(def: ChestDef, node: SKSpriteNode)] = []

    // MARK: - Interface

    private let hud = HUDNode()
    private let joystick = VirtualJoystick()
    private var dialogue: DialogueBox!
    private var actionButton: PaperButton!
    private var menuButton: PaperButton!
    private var menuOverlay: MenuOverlay?
    private var shopOverlay: ShopOverlay?

    // MARK: - State

    private let state = GameState.shared
    private var stepsSinceEncounter: CGFloat = 0
    private var distanceToNextEncounter: CGFloat = 0
    private var pendingTarget: Interaction?
    private var isBusy = false                  // suppresses input during transitions

    private enum Interaction {
        case npc(NPCDef)
        case chest(ChestDef)
        case exit(ExitDef)

        var prompt: String {
            switch self {
            case .npc: return "TALK"
            case .chest: return "OPEN"
            case .exit(let e): return e.label.uppercased().contains("BACK") ? "GO BACK" : "GO"
            }
        }
    }

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = Paper.background
        scaleMode = .resizeFill
        Haptics.prepare()

        buildWorld()
        buildInterface()
        rollNextEncounterDistance()
        hud.refresh(from: state)
    }

    override func willMove(from view: SKView) {
        persistPosition()
    }

    // MARK: - Building

    private func buildWorld() {
        removeAllChildren()
        worldNode.removeAllChildren()

        let definition = MapCatalog.map(id: state.save.mapID)
        mapNode = TileMapNode(definition: definition)
        worldNode.addChild(mapNode)
        addChild(worldNode)

        player.position = mapNode.position(ofTileX: state.save.tileX, y: state.save.tileY)
        player.zPosition = Layer.entity(y: player.position.y)
        mapNode.propLayer.addChild(player)

        buildNPCs(definition)
        buildChests(definition)
        buildExitMarkers(definition)

        camera = cameraNode
        addChild(cameraNode)
        centreCamera(on: player.position, animated: false)
    }

    private func buildNPCs(_ definition: MapDef) {
        npcNodes.removeAll()
        for npc in definition.npcs {
            if let flag = npc.hiddenWhenFlag, state.has(flag: flag) { continue }

            let texture = Art.texture(npc.spriteName, in: npc.spriteFolder)
            let sprite = SKSpriteNode(texture: texture)
            let height = Paper.tileSize * npc.scale
            let ratio = texture.size().width / max(1, texture.size().height)
            sprite.size = CGSize(width: height * ratio, height: height)
            sprite.anchorPoint = CGPoint(x: 0.5, y: 0.08)
            sprite.position = mapNode.position(ofTileX: npc.x, y: npc.y)
            sprite.zPosition = Layer.entity(y: sprite.position.y)
            mapNode.propLayer.addChild(sprite)

            // A gentle bob so the world feels drawn-by-hand rather than static.
            sprite.run(.repeatForever(.sequence([
                .moveBy(x: 0, y: 4, duration: 1.1),
                .moveBy(x: 0, y: -4, duration: 1.1)
            ])))

            npcNodes.append((npc, sprite))
        }
    }

    private func buildChests(_ definition: MapDef) {
        chestNodes.removeAll()
        for chest in definition.chests {
            let opened = state.has(flag: "chest_" + chest.id)
            let sprite = SKSpriteNode(texture: Art.texture(opened ? "chest_open" : "chest",
                                                           in: "props"))
            let height = Paper.tileSize * 0.85
            let ratio = sprite.texture.map { $0.size().width / max(1, $0.size().height) } ?? 1
            sprite.size = CGSize(width: height * ratio, height: height)
            sprite.anchorPoint = CGPoint(x: 0.5, y: 0.1)
            sprite.position = mapNode.position(ofTileX: chest.x, y: chest.y)
            sprite.zPosition = Layer.entity(y: sprite.position.y)
            mapNode.propLayer.addChild(sprite)
            chestNodes.append((chest, sprite))
        }
    }

    private func buildExitMarkers(_ definition: MapDef) {
        for exit in definition.exits {
            let marker = SKSpriteNode(texture: Art.texture("signpost", in: "props"))
            let height = Paper.tileSize * 0.9
            let ratio = marker.texture.map { $0.size().width / max(1, $0.size().height) } ?? 1
            marker.size = CGSize(width: height * ratio, height: height)
            marker.anchorPoint = CGPoint(x: 0.5, y: 0.1)
            marker.position = mapNode.position(ofTileX: exit.x, y: exit.y)
            marker.zPosition = Layer.entity(y: marker.position.y)
            marker.alpha = 0.9
            mapNode.propLayer.addChild(marker)
        }
    }

    private func buildInterface() {
        cameraNode.removeAllChildren()

        let halfWidth = size.width / 2
        let halfHeight = size.height / 2
        let inset: CGFloat = 26
        let safeTop = (view?.safeAreaInsets.top ?? 0)
        let safeBottom = (view?.safeAreaInsets.bottom ?? 0)

        hud.position = CGPoint(x: -halfWidth + inset, y: halfHeight - safeTop - 34)
        cameraNode.addChild(hud)

        joystick.place(at: CGPoint(x: -halfWidth + 128, y: -halfHeight + safeBottom + 130))
        joystick.alpha = 0.55
        cameraNode.addChild(joystick)

        actionButton = PaperButton(title: "TALK",
                                   size: CGSize(width: 168, height: 78),
                                   fontSize: 24) { [weak self] in
            self?.performInteraction()
        }
        actionButton.position = CGPoint(x: halfWidth - 118, y: -halfHeight + safeBottom + 128)
        actionButton.zPosition = Layer.ui
        actionButton.alpha = 0
        actionButton.isHidden = true
        cameraNode.addChild(actionButton)

        menuButton = PaperButton(title: "BAG",
                                 size: CGSize(width: 116, height: 62),
                                 fontSize: 20) { [weak self] in
            self?.openMenu()
        }
        menuButton.position = CGPoint(x: halfWidth - 84, y: halfHeight - safeTop - 46)
        menuButton.zPosition = Layer.ui
        cameraNode.addChild(menuButton)

        dialogue = DialogueBox(width: min(size.width - 48, 720))
        dialogue.position = CGPoint(x: 0, y: -halfHeight + safeBottom + dialogue.height / 2 + 26)
        cameraNode.addChild(dialogue)
    }

    // MARK: - Frame update

    override func update(_ currentTime: TimeInterval) {
        guard !isBusy, !dialogue.isPresenting, menuOverlay == nil, shopOverlay == nil else {
            player.update(direction: .zero)
            return
        }

        let dt: CGFloat = 1.0 / 60.0
        let input = joystick.vector
        move(by: input, dt: dt)
        player.update(direction: input)
        centreCamera(on: player.position, animated: true)
        refreshInteractionPrompt()
    }

    private func move(by input: CGVector, dt: CGFloat) {
        guard abs(input.dx) > 0.01 || abs(input.dy) > 0.01 else { return }

        let step = CGVector(dx: input.dx * walkSpeed * dt,
                            dy: input.dy * walkSpeed * dt)
        let radius = player.bodyRadius
        var moved = false

        // Resolve each axis separately so sliding along a wall feels natural
        // instead of sticking.
        let horizontal = CGPoint(x: player.position.x + step.dx, y: player.position.y)
        if mapNode.canStand(at: horizontal, radius: radius) {
            player.position.x = horizontal.x
            moved = true
        }

        let vertical = CGPoint(x: player.position.x, y: player.position.y + step.dy)
        if mapNode.canStand(at: vertical, radius: radius) {
            player.position.y = vertical.y
            moved = true
        }

        if !moved {
            player.nudge()
            return
        }

        player.zPosition = Layer.entity(y: player.position.y)

        let travelled = sqrt(step.dx * step.dx + step.dy * step.dy)
        accumulateEncounter(distance: travelled)
        checkAutomaticExit()
    }

    private func centreCamera(on point: CGPoint, animated: Bool) {
        let world = mapNode.worldSize
        let halfWidth = size.width / 2
        let halfHeight = size.height / 2

        // Clamp so the camera never shows past the edge of the page, unless the
        // map is smaller than the screen, in which case centre it.
        let x: CGFloat = world.width <= size.width
            ? world.width / 2
            : min(max(point.x, halfWidth), world.width - halfWidth)
        let y: CGFloat = world.height <= size.height
            ? world.height / 2
            : min(max(point.y, halfHeight), world.height - halfHeight)

        let target = CGPoint(x: x, y: y)
        if animated {
            // A little lag makes the camera feel less rigid.
            cameraNode.position = CGPoint(
                x: cameraNode.position.x + (target.x - cameraNode.position.x) * 0.18,
                y: cameraNode.position.y + (target.y - cameraNode.position.y) * 0.18)
        } else {
            cameraNode.position = target
        }
    }

    // MARK: - Interaction

    private func nearestInteraction() -> Interaction? {
        var best: (distance: CGFloat, interaction: Interaction)?

        func consider(_ point: CGPoint, _ interaction: Interaction) {
            let dx = point.x - player.position.x
            let dy = point.y - player.position.y
            let distance = sqrt(dx * dx + dy * dy)
            guard distance <= interactionRange else { return }
            if best == nil || distance < best!.distance {
                best = (distance, interaction)
            }
        }

        for entry in npcNodes {
            consider(entry.node.position, .npc(entry.def))
        }
        for entry in chestNodes where !state.has(flag: "chest_" + entry.def.id) {
            consider(entry.node.position, .chest(entry.def))
        }
        for exit in mapNode.definition.exits {
            consider(mapNode.position(ofTileX: exit.x, y: exit.y), .exit(exit))
        }

        return best?.interaction
    }

    private func refreshInteractionPrompt() {
        let target = nearestInteraction()
        pendingTarget = target

        let shouldShow = target != nil
        if shouldShow, actionButton.isHidden {
            actionButton.isHidden = false
            actionButton.run(.fadeIn(withDuration: 0.12))
        } else if !shouldShow, !actionButton.isHidden {
            actionButton.run(.sequence([
                .fadeOut(withDuration: 0.12),
                .run { [weak self] in self?.actionButton.isHidden = true }
            ]))
        }
        if let target { actionButton.title = target.prompt }
    }

    private func performInteraction() {
        guard let target = pendingTarget, !dialogue.isPresenting else { return }

        switch target {
        case .npc(let npc):
            talk(to: npc)
        case .chest(let chest):
            open(chest)
        case .exit(let exit):
            travel(through: exit)
        }
    }

    private func talk(to npc: NPCDef) {
        dialogue.present(npc.lines) { [weak self] in
            guard let self else { return }
            if npc.restores {
                self.state.fullRestore()
                self.hud.refresh(from: self.state)
                Haptics.success()
            }
            if npc.opensShop {
                self.openShop()
            }
            if let bossID = npc.bossID, let def = Bestiary.definition(id: bossID) {
                self.startBattle(with: def, isBoss: true)
            }
        }
    }

    private func open(_ chest: ChestDef) {
        state.set(flag: "chest_" + chest.id)

        var rewards: [String] = []
        if let itemID = chest.itemID, let item = ItemCatalog.item(id: itemID) {
            state.addItem(itemID)
            rewards.append(item.name)
        }
        if let gearID = chest.equipmentID, let gear = EquipmentCatalog.equipment(id: gearID) {
            state.grantEquipment(gearID)
            state.equip(gearID)
            rewards.append("\(gear.name) (equipped)")
        }
        if chest.coins > 0 {
            state.addCoins(chest.coins)
            rewards.append("\(chest.coins) coins")
        }
        state.persist()

        if let entry = chestNodes.first(where: { $0.def.id == chest.id }) {
            entry.node.texture = Art.texture("chest_open", in: "props")
            entry.node.run(.sequence([
                .scale(to: 1.15, duration: 0.1),
                .scale(to: 1.0, duration: 0.12)
            ]))
        }

        Haptics.success()
        hud.refresh(from: state)
        dialogue.present(["You found " + rewards.joined(separator: ", ") + "."])
    }

    private func travel(through exit: ExitDef) {
        guard !isBusy else { return }
        isBusy = true
        joystick.reset()
        persistPosition()

        let fade = SKSpriteNode(color: Paper.background, size: size)
        fade.zPosition = Layer.ui + 500
        fade.alpha = 0
        cameraNode.addChild(fade)

        fade.run(.sequence([
            .fadeIn(withDuration: 0.22),
            .run { [weak self] in
                guard let self else { return }
                self.state.setPosition(mapID: exit.targetMap, x: exit.targetX, y: exit.targetY)
                self.state.persist()
                self.buildWorld()
                self.buildInterface()
                self.rollNextEncounterDistance()
                self.hud.refresh(from: self.state)

                let banner = Paper.label(MapCatalog.map(id: exit.targetMap).name, size: 30)
                banner.position = CGPoint(x: 0, y: self.size.height * 0.24)
                banner.zPosition = Layer.ui + 400
                self.cameraNode.addChild(banner)
                banner.run(.sequence([
                    .wait(forDuration: 1.3),
                    .fadeOut(withDuration: 0.4),
                    .removeFromParent()
                ]))
            },
            .wait(forDuration: 0.05)
        ])) { [weak self] in
            guard let self else { return }
            // buildInterface replaced the camera's children, so fade back in
            // using a fresh overlay.
            let cover = SKSpriteNode(color: Paper.background, size: self.size)
            cover.zPosition = Layer.ui + 500
            self.cameraNode.addChild(cover)
            cover.run(.sequence([
                .fadeOut(withDuration: 0.28),
                .removeFromParent(),
                .run { self.isBusy = false }
            ]))
        }
    }

    /// Stepping directly onto an exit tile also travels, so the signpost is a
    /// hint rather than a requirement.
    private func checkAutomaticExit() {
        guard !isBusy else { return }
        let tile = mapNode.tile(at: player.position)
        guard let exit = mapNode.definition.exits.first(where: { $0.x == tile.x && $0.y == tile.y })
        else { return }
        travel(through: exit)
    }

    // MARK: - Encounters

    private func rollNextEncounterDistance() {
        let rate = max(0.001, mapNode.definition.encounterRate)
        // Convert a per-tile chance into an expected distance, with variance so
        // encounters never feel metronomic.
        let expectedTiles = 1.0 / rate
        let tiles = Double.random(in: expectedTiles * 0.45...expectedTiles * 1.55)
        distanceToNextEncounter = CGFloat(tiles) * Paper.tileSize
        stepsSinceEncounter = 0
    }

    private func accumulateEncounter(distance: CGFloat) {
        guard !mapNode.definition.encounterPool.isEmpty else { return }

        let tile = mapNode.tile(at: player.position)
        guard !mapNode.isSafe(x: tile.x, y: tile.y) else { return }

        stepsSinceEncounter += distance
        guard stepsSinceEncounter >= distanceToNextEncounter else { return }

        let pool = mapNode.definition.encounterPool
        guard let id = pool.randomElement(), let def = Bestiary.definition(id: id) else { return }
        rollNextEncounterDistance()
        startBattle(with: def, isBoss: false)
    }

    private func startBattle(with enemy: EnemyDef, isBoss: Bool) {
        guard !isBusy else { return }
        isBusy = true
        joystick.reset()
        persistPosition()
        Haptics.bigHit()

        // A quick ink-splash wipe stands in for the classic RPG battle swirl.
        let flash = SKSpriteNode(color: Paper.ink, size: size)
        flash.zPosition = Layer.ui + 600
        flash.alpha = 0
        cameraNode.addChild(flash)
        flash.run(.sequence([
            .fadeAlpha(to: 0.9, duration: 0.12),
            .fadeAlpha(to: 0.2, duration: 0.08),
            .fadeAlpha(to: 1.0, duration: 0.14),
            .run { [weak self] in
                guard let self, let view = self.view else { return }
                let battle = BattleScene(size: self.size, enemy: enemy, isBoss: isBoss)
                battle.scaleMode = .resizeFill
                view.presentScene(battle, transition: .fade(with: Paper.ink, duration: 0.25))
            }
        ]))
    }

    // MARK: - Overlays

    private func openMenu() {
        guard menuOverlay == nil, shopOverlay == nil, !dialogue.isPresenting else { return }
        joystick.reset()
        let overlay = MenuOverlay(size: size) { [weak self] in
            self?.closeMenu()
        }
        overlay.zPosition = Layer.ui + 300
        cameraNode.addChild(overlay)
        menuOverlay = overlay
    }

    private func closeMenu() {
        menuOverlay?.removeFromParent()
        menuOverlay = nil
        hud.refresh(from: state)
    }

    private func openShop() {
        guard shopOverlay == nil else { return }
        joystick.reset()
        let overlay = ShopOverlay(size: size) { [weak self] in
            self?.closeShop()
        }
        overlay.zPosition = Layer.ui + 300
        cameraNode.addChild(overlay)
        shopOverlay = overlay
    }

    private func closeShop() {
        shopOverlay?.removeFromParent()
        shopOverlay = nil
        hud.refresh(from: state)
    }

    // MARK: - Persistence

    private func persistPosition() {
        guard mapNode != nil else { return }
        let tile = mapNode.tile(at: player.position)
        guard mapNode.isWalkable(x: tile.x, y: tile.y) else {
            // Never save a tile the player could not stand on after a reload.
            state.persist()
            return
        }
        state.setPosition(mapID: mapNode.definition.id, x: tile.x, y: tile.y)
        state.persist()
    }

    // MARK: - Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard menuOverlay == nil, shopOverlay == nil else { return }

        for touch in touches {
            let scenePoint = touch.location(in: self)

            if dialogue.isPresenting {
                dialogue.advance()
                return
            }

            // Anywhere on the left half acts as the joystick area.
            let cameraPoint = touch.location(in: cameraNode)
            if cameraPoint.x < 0 && !actionButton.contains(scenePoint: scenePoint) {
                _ = joystick.begin(touch: touch, at: cameraPoint)
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            joystick.move(touch: touch, to: touch.location(in: cameraNode))
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { joystick.end(touch: touch) }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { joystick.end(touch: touch) }
    }
}
