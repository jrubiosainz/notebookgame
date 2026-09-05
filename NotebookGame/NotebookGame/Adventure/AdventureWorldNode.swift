import SpriteKit

final class AdventureWorldNode: SKNode {
    static let tile: CGFloat = 58
    private let ground = SKNode()
    private let inkLayer = SKNode()
    private let objectsLayer = SKNode()
    private let structuresLayer = SKNode()
    private let enemiesLayer = SKNode()
    private let hero = NibAnimator()
    private var objectNodes: [String: SKNode] = [:]
    private var creatureNodes: [String: SKSpriteNode] = [:]
    private var renderedInk: Set<PagePoint> = []
    private var inkNodes: [PagePoint: SKNode] = [:]
    private var buildsSignature = ""
    private var paintedSignature: Set<String> = []
    private var collectedSignature: Set<String> = []
    private var harvestSignature: [String: Int] = [:]
    private var lastDay = 0
    private var pageID = ""
    private var animationTime: Double = 0
    private var lastHeroX: Double = 0
    private var lastHeroY: Double = 0
    private let target = SKShapeNode(rectOf: CGSize(width: 52, height: 52), cornerRadius: 8)
    private let heroLight = SKNode()

    override init() {
        super.init()
        addChild(ground)
        inkLayer.zPosition = 2
        addChild(inkLayer)
        addChild(objectsLayer)
        addChild(structuresLayer)
        addChild(enemiesLayer)
        addChild(hero)
        heroLight.zPosition = 3
        addChild(heroLight)
        for i in (1...5).reversed() {
            let glow = NotebookVisuals.wash(radius: CGFloat(i) * 29,
                                            color: NotebookVisuals.gold.withAlphaComponent(0.025))
            heroLight.addChild(glow)
        }
        target.lineWidth = 2
        target.fillColor = .clear
        target.zPosition = 4
        addChild(target)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    static func position(x: Double, y: Double) -> CGPoint {
        CGPoint(x: CGFloat(x) * tile, y: CGFloat(y) * tile)
    }

    static func position(_ point: PagePoint) -> CGPoint {
        position(x: Double(point.x), y: Double(point.y))
    }

    func rebuild(_ engine: AdventureEngine) {
        pageID = engine.page.id
        ground.removeAllChildren()
        inkLayer.removeAllChildren()
        objectsLayer.removeAllChildren()
        structuresLayer.removeAllChildren()
        enemiesLayer.removeAllChildren()
        objectNodes.removeAll()
        creatureNodes.removeAll()
        inkNodes.removeAll()
        renderedInk = []
        buildsSignature = ""
        paintedSignature = engine.save.painted
        collectedSignature = engine.save.collected
        harvestSignature = engine.save.harvestedDay
        lastDay = engine.day
        lastHeroX = engine.save.x
        lastHeroY = engine.save.y
        hero.reset(facing: NibAnimator.Facing(direction: CGVector(dx: CGFloat(engine.save.facing.x),
                                                                dy: CGFloat(engine.save.facing.y))))
        let page = engine.page
        let w = CGFloat(page.width) * Self.tile
        let h = CGFloat(page.height) * Self.tile
        let sheet = SKSpriteNode(color: NotebookVisuals.paper, size: CGSize(width: w, height: h))
        sheet.position = CGPoint(x: w / 2 - Self.tile / 2, y: h / 2 - Self.tile / 2)
        ground.addChild(sheet)
        let grain = NotebookVisuals.sprite("paper", folder: "tiles", height: h)
        grain.size = CGSize(width: w, height: h)
        grain.alpha = 0.12
        grain.position = sheet.position
        ground.addChild(grain)
        for row in 0...page.height * 2 {
            let rule = NotebookVisuals.rule(width: w, color: NotebookVisuals.blue.withAlphaComponent(0.15))
            rule.position = CGPoint(x: sheet.position.x, y: CGFloat(row) * Self.tile / 2)
            ground.addChild(rule)
        }
        let margin = SKShapeNode(rectOf: CGSize(width: 1.2, height: h))
        margin.position = CGPoint(x: Self.tile * 1.1, y: sheet.position.y)
        margin.fillColor = NotebookVisuals.color(.red).withAlphaComponent(0.24)
        margin.strokeColor = .clear
        ground.addChild(margin)
        for y in stride(from: 2, to: page.height, by: 3) {
            let hole = SKShapeNode(ellipseOf: CGSize(width: 15, height: 23))
            hole.fillColor = SKColor(white: 0.77, alpha: 1)
            hole.strokeColor = NotebookVisuals.muted.withAlphaComponent(0.3)
            hole.position = CGPoint(x: 9, y: CGFloat(y) * Self.tile)
            ground.addChild(hole)
        }
        let path = CGMutablePath()
        path.move(to: CGPoint(x: w * 0.2, y: Self.tile))
        path.addCurve(to: CGPoint(x: w * 0.76, y: h - Self.tile),
                      control1: CGPoint(x: w * 0.86, y: h * 0.30),
                      control2: CGPoint(x: w * 0.12, y: h * 0.73))
        let trail = SKShapeNode(path: path)
        trail.strokeColor = SKColor(red: 0.77, green: 0.72, blue: 0.59, alpha: 0.14)
        trail.lineWidth = 43
        ground.addChild(trail)

        for point in page.blocked.sorted(by: { $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y }) {
            let rocky = page.depth > 0 || point.x % 3 == 0
            let tree = NotebookVisuals.sprite(rocky ? "rock_large" : "tree_pine",
                                               height: rocky ? 68 : 110)
            tree.anchorPoint = CGPoint(x: 0.5, y: 0.10)
            tree.position = Self.position(point)
            tree.alpha = 0.85
            tree.zPosition = 2000 - tree.position.y
            objectsLayer.addChild(tree)
        }
        for y in 2..<(page.height - 1) {
            for x in 2..<(page.width - 1) where (x * 13 + y * 19 + page.number) % 23 == 0 {
                let point = PagePoint(x: x, y: y)
                guard !page.blocked.contains(point),
                      !page.objects.contains(where: { $0.point == point }) else { continue }
                let doodle = NotebookVisuals.sprite((x + y) % 2 == 0 ? "grass_tuft" : "flower",
                                                    height: 18 + CGFloat(x % 3) * 4)
                doodle.alpha = 0.32
                doodle.position = Self.position(point)
                ground.addChild(doodle)
            }
        }
        let note = NotebookVisuals.label(page.flavor, size: 17, color: NotebookVisuals.muted)
        note.position = Self.position(x: Double(page.width) / 2, y: Double(page.height) - 2)
        note.zRotation = -0.04
        ground.addChild(note)
        rebuildObjects(engine)
        refresh(engine, dt: 0)
    }

    private func rebuildObjects(_ engine: AdventureEngine) {
        objectNodes.values.forEach { $0.removeFromParent() }
        objectNodes.removeAll()
        for object in engine.page.objects {
            let openedChest = object.kind == .chest && engine.save.collected.contains(object.id)
            guard engine.isAvailable(object) || openedChest else { continue }
            let node = SKNode()
            node.position = Self.position(object.point)
            node.zPosition = 2100 - node.position.y
            objectNodes[object.id] = node
            objectsLayer.addChild(node)
            let painted = engine.save.painted.contains(object.id)
            if object.kind == .pigment, let pigment = object.pigment {
                let wash = NotebookVisuals.wash(radius: 28, color: NotebookVisuals.color(pigment).withAlphaComponent(0.25))
                node.addChild(wash)
                let bottle = NotebookVisuals.sprite("inkwell", height: 45)
                bottle.color = NotebookVisuals.color(pigment)
                bottle.colorBlendFactor = 0.7
                bottle.position.y = 19
                node.addChild(bottle)
                let mote = SKShapeNode(circleOfRadius: 4)
                mote.fillColor = NotebookVisuals.color(pigment)
                mote.strokeColor = .clear
                mote.position = CGPoint(x: 0, y: 56)
                mote.run(.repeatForever(.sequence([.moveBy(x: 0, y: 7, duration: 1),
                                                  .moveBy(x: 0, y: -7, duration: 1)])))
                node.addChild(mote)
            } else {
                let height: CGFloat
                switch object.kind {
                case .tree: height = 105
                case .npc: height = 78
                case .inkwell: height = 100
                case .gate: height = 65
                case .berries: height = 51
                case .scraps: height = 30
                case .memory: height = 35
                default: height = 47
                }
                if object.kind == .scraps || object.kind == .memory {
                    for i in 0..<3 {
                        let fill = painted ? object.pigment.map(NotebookVisuals.color) ?? NotebookVisuals.paper
                            : NotebookVisuals.paper
                        let scrap = NotebookVisuals.card(CGSize(width: 26, height: 19), fill: fill, radius: 1)
                        scrap.position = CGPoint(x: CGFloat(i - 1) * 6, y: CGFloat(i) * 3)
                        scrap.zRotation = CGFloat(i - 1) * 0.23
                        node.addChild(scrap)
                        let rule = NotebookVisuals.rule(width: 16, color: object.kind == .memory
                                                         ? NotebookVisuals.color(.violet) : NotebookVisuals.muted)
                        scrap.addChild(rule)
                    }
                } else if object.kind == .gate {
                    drawGate(object, painted: painted, in: node)
                } else {
                    let sprite = NotebookVisuals.sprite(openedChest ? "chest_open" : object.art,
                                                         folder: object.folder, height: height)
                    sprite.anchorPoint = CGPoint(x: 0.5, y: 0.07)
                    if painted, let pigment = object.pigment {
                        sprite.color = NotebookVisuals.color(pigment)
                        sprite.colorBlendFactor = 0.60
                        let stain = NotebookVisuals.wash(radius: height * 0.4,
                                                        color: NotebookVisuals.color(pigment).withAlphaComponent(0.13))
                        stain.zPosition = -1
                        node.addChild(stain)
                    } else if object.pigment != nil {
                        sprite.alpha = 0.50
                    }
                    node.addChild(sprite)
                }
                if let pigment = object.pigment, !painted {
                    let badge = SKShapeNode(circleOfRadius: 8)
                    badge.fillColor = NotebookVisuals.paper
                    badge.strokeColor = NotebookVisuals.color(pigment)
                    badge.lineWidth = 2
                    badge.position = CGPoint(x: 22, y: 36)
                    node.addChild(badge)
                    let dot = NotebookVisuals.label("?", size: 10, color: NotebookVisuals.color(pigment))
                    badge.addChild(dot)
                }
            }
            if [.npc, .gate, .pigment, .inkwell].contains(object.kind) {
                let title = NotebookVisuals.label(object.kind == .pigment
                                                 ? object.pigment?.title.uppercased() ?? object.name
                                                 : object.name, size: 10,
                                                 color: NotebookVisuals.muted, sans: true)
                title.position.y = -15
                let backing = NotebookVisuals.card(CGSize(width: title.frame.width + 12, height: 19),
                                                   radius: 3)
                backing.position.y = -15
                backing.lineWidth = 0
                node.addChild(backing)
                title.zPosition = 1
                node.addChild(title)
            }
        }
    }

    func refresh(_ engine: AdventureEngine, dt: Double, buildMode: BuildKind? = nil) {
        if pageID != engine.page.id { rebuild(engine); return }
        animationTime += dt
        hero.position = Self.position(x: engine.save.x, y: engine.save.y)
        hero.zPosition = 2101 - hero.position.y
        let displacement = CGVector(dx: engine.save.x - lastHeroX, dy: engine.save.y - lastHeroY)
        hero.update(dt: dt, displacement: displacement,
                    heading: CGVector(dx: CGFloat(engine.save.facing.x), dy: CGFloat(engine.save.facing.y)))
        lastHeroX = engine.save.x
        lastHeroY = engine.save.y
        heroLight.position = hero.position
        heroLight.alpha = engine.isNight ? 1 : 0
        if engine.save.painted != paintedSignature || engine.save.collected != collectedSignature
            || engine.save.harvestedDay != harvestSignature || lastDay != engine.day {
            paintedSignature = engine.save.painted
            collectedSignature = engine.save.collected
            lastDay = engine.day
            harvestSignature = engine.save.harvestedDay
            rebuildObjects(engine)
        }
        let newInk = engine.inkTiles
        for point in renderedInk.subtracting(newInk) {
            inkNodes.removeValue(forKey: point)?.removeFromParent()
        }
        for point in newInk.subtracting(renderedInk) {
            let stain = NotebookVisuals.wash(radius: Self.tile * 0.73,
                                             color: SKColor(red: 0.13, green: 0.15, blue: 0.20, alpha: 0.94),
                                             seed: point.x + point.y)
            stain.position = Self.position(point)
            let sheen = NotebookVisuals.rule(width: 20, color: SKColor(white: 0.60, alpha: 0.25))
            sheen.zRotation = 0.3
            stain.addChild(sheen)
            inkLayer.addChild(stain)
            inkNodes[point] = stain
        }
        renderedInk = newInk
        let builds = engine.save.builds.filter { $0.pageID == engine.page.id }
        let signature = builds.map { "\($0.id):\($0.fuel > 0)" }.joined(separator: "|")
        if signature != buildsSignature {
            buildsSignature = signature
            structuresLayer.removeAllChildren()
            for build in builds { drawBuild(build) }
        }
        let creatures = engine.save.creatures.filter { $0.pageID == engine.page.id && $0.remaining > 0 }
        let ids = Set(creatures.map(\.id))
        for id in Array(creatureNodes.keys) where !ids.contains(id) {
            creatureNodes.removeValue(forKey: id)?.run(.sequence([
                .group([.fadeOut(withDuration: 0.2), .scale(to: 0.7, duration: 0.2)]),
                .removeFromParent()
            ]))
        }
        for creature in creatures {
            let sprite: SKSpriteNode
            if let current = creatureNodes[creature.id] { sprite = current } else {
                sprite = NotebookVisuals.sprite(engine.page.depth > 1 ? "smudge" : "ink_slime",
                                                 folder: "enemies", height: 47)
                creatureNodes[creature.id] = sprite
                enemiesLayer.addChild(sprite)
            }
            sprite.position = Self.position(x: creature.x, y: creature.y)
            sprite.position.y += sin(animationTime * 3 + creature.x) * 3
            sprite.zPosition = 2100 - sprite.position.y
            sprite.alpha = max(0.08, creature.remaining)
        }
        target.isHidden = buildMode == nil
        if let kind = buildMode {
            target.position = Self.position(engine.targetPoint)
            target.strokeColor = engine.canBuild(kind, at: engine.targetPoint)
                ? NotebookVisuals.color(.green) : NotebookVisuals.color(.red)
        }
    }

    private func drawGate(_ object: AdventureObject, painted: Bool, in node: SKNode) {
        let color = painted ? object.pigment.map(NotebookVisuals.color) ?? NotebookVisuals.paper
            : NotebookVisuals.paper
        if object.id.contains("archive_margin") || object.id.contains("origin_garden") {
            let arch = SKShapeNode(ellipseOf: CGSize(width: 50, height: 64))
            arch.position.y = 22
            arch.fillColor = painted ? NotebookVisuals.ink : NotebookVisuals.muted.withAlphaComponent(0.3)
            arch.strokeColor = color
            arch.lineWidth = 9
            node.addChild(arch)
            for i in 0..<5 {
                let line = NotebookVisuals.rule(width: 8)
                let a = CGFloat(i) / 4 * .pi
                line.position = CGPoint(x: cos(a) * 23, y: 22 + sin(a) * 30)
                line.zRotation = a
                node.addChild(line)
            }
        } else {
            for i in 0..<5 {
                let step = NotebookVisuals.card(CGSize(width: 49 - CGFloat(i) * 3, height: 12),
                                                fill: color, radius: 1)
                step.position = CGPoint(x: 0, y: CGFloat(i) * 11)
                step.zRotation = CGFloat(i % 2) * 0.035
                node.addChild(step)
            }
            let arrow = NotebookVisuals.label("^", size: 26,
                                              color: painted ? NotebookVisuals.paper : NotebookVisuals.muted)
            arrow.position.y = 23
            node.addChild(arrow)
        }
        node.alpha = painted ? 1 : 0.63
    }

    private func drawBuild(_ build: PlacedBuild) {
        let node = SKNode()
        node.position = Self.position(build.point)
        node.zPosition = build.kind == .path ? 3 : 2100 - node.position.y
        structuresLayer.addChild(node)
        switch build.kind {
        case .path:
            for i in 0..<4 {
                let plank = NotebookVisuals.card(CGSize(width: 52, height: 12),
                                                 fill: NotebookVisuals.paper, radius: 1)
                plank.position.y = CGFloat(i) * 13 - 20
                plank.zRotation = i % 2 == 0 ? 0.03 : -0.02
                node.addChild(plank)
            }
        case .wall:
            for i in 0..<5 {
                let post = NotebookVisuals.card(CGSize(width: 10, height: 44),
                                                fill: NotebookVisuals.color(.brown), radius: 2)
                post.position = CGPoint(x: CGFloat(i) * 11 - 22, y: 14)
                post.zRotation = CGFloat(i % 2) * 0.05
                node.addChild(post)
                let grain = NotebookVisuals.rule(width: 27, color: NotebookVisuals.paper.withAlphaComponent(0.5))
                grain.zRotation = .pi / 2
                post.addChild(grain)
            }
        case .campfire:
            if build.fuel > 0 {
                for i in (1...5).reversed() {
                    let glow = NotebookVisuals.wash(radius: CGFloat(i) * 37,
                                                    color: NotebookVisuals.color(.yellow).withAlphaComponent(0.055))
                    glow.zPosition = -2
                    node.addChild(glow)
                }
            }
            let fire = NotebookVisuals.sprite("campfire", height: 57)
            fire.position.y = 18
            if build.fuel > 0 {
                fire.color = NotebookVisuals.color(.yellow)
                fire.colorBlendFactor = 0.6
                fire.run(.repeatForever(.sequence([.scaleY(to: 1.06, duration: 0.3),
                                                  .scaleY(to: 0.95, duration: 0.25)])))
                for i in 0..<4 {
                    let spark = SKShapeNode(circleOfRadius: 1.6)
                    spark.fillColor = NotebookVisuals.color(.red)
                    spark.strokeColor = .clear
                    spark.position = CGPoint(x: CGFloat(i) * 7 - 10, y: 29)
                    spark.run(.repeatForever(.sequence([
                        .group([.moveBy(x: 4, y: 33, duration: 1.2), .fadeOut(withDuration: 1.2)]),
                        .moveBy(x: -4, y: -33, duration: 0), .fadeIn(withDuration: 0)
                    ])))
                    node.addChild(spark)
                }
            } else { fire.alpha = 0.45 }
            node.addChild(fire)
        case .shelter:
            let roofPath = CGMutablePath()
            roofPath.move(to: CGPoint(x: -39, y: -5))
            roofPath.addLine(to: CGPoint(x: 0, y: 68))
            roofPath.addLine(to: CGPoint(x: 44, y: -5))
            roofPath.closeSubpath()
            let roof = SKShapeNode(path: roofPath)
            roof.fillColor = NotebookVisuals.color(.green).withAlphaComponent(0.80)
            roof.strokeColor = NotebookVisuals.ink
            roof.lineWidth = 2
            node.addChild(roof)
            let opening = CGMutablePath()
            opening.move(to: CGPoint(x: -12, y: -4))
            opening.addLine(to: CGPoint(x: 0, y: 38))
            opening.addLine(to: CGPoint(x: 19, y: -4))
            let door = SKShapeNode(path: opening)
            door.fillColor = NotebookVisuals.ink
            node.addChild(door)
            let banner = NotebookVisuals.label("HOGAR", size: 10, color: NotebookVisuals.paper, sans: true)
            banner.position.y = 46
            node.addChild(banner)
        }
    }

    func paintEffect(at point: PagePoint, pigment: Pigment, animateHero: Bool = true) {
        if animateHero {
            let direction = CGVector(dx: Self.position(point).x - hero.position.x,
                                     dy: Self.position(point).y - hero.position.y)
            hero.play(.paint(pigment), toward: direction)
            let path = CGMutablePath()
            let start = CGPoint(x: hero.position.x, y: hero.position.y + 29)
            let end = Self.position(point)
            path.move(to: start)
            path.addQuadCurve(to: end, control: CGPoint(x: (start.x + end.x) / 2,
                                                        y: max(start.y, end.y) + 33))
            let dab = NotebookVisuals.wash(radius: 5, color: NotebookVisuals.color(pigment))
            dab.position = start
            dab.zPosition = 4001
            addChild(dab)
            dab.run(.sequence([.wait(forDuration: 0.08),
                               .follow(path, asOffset: false, orientToPath: false, duration: 0.20),
                               .removeFromParent()]))
        }
        let wash = NotebookVisuals.wash(radius: 45, color: NotebookVisuals.color(pigment).withAlphaComponent(0.6))
        wash.position = Self.position(point)
        wash.zPosition = 4000
        addChild(wash)
        wash.run(.sequence([.group([.scale(to: 2, duration: 0.55), .fadeOut(withDuration: 0.55)]),
                            .removeFromParent()]))
        for i in 0..<12 {
            let dot = SKShapeNode(circleOfRadius: CGFloat(2 + i % 3))
            dot.fillColor = NotebookVisuals.color(pigment)
            dot.strokeColor = .clear
            dot.position = Self.position(point)
            dot.zPosition = 4001
            addChild(dot)
            let a = CGFloat(i) / 12 * .pi * 2
            dot.run(.sequence([.group([.moveBy(x: cos(a) * 66, y: sin(a) * 52, duration: 0.6),
                                       .fadeOut(withDuration: 0.6)]), .removeFromParent()]))
        }
    }

    func eraseEffect(reach: Double, facing: PagePoint) {
        hero.play(.erase, toward: CGVector(dx: CGFloat(facing.x), dy: CGFloat(facing.y)))
        let circle = SKShapeNode(circleOfRadius: CGFloat(reach) * Self.tile)
        circle.position = hero.position
        circle.strokeColor = NotebookVisuals.paper
        circle.lineWidth = 12
        circle.fillColor = NotebookVisuals.paper.withAlphaComponent(0.16)
        circle.zPosition = 4000
        circle.setScale(0.35)
        addChild(circle)
        circle.run(.sequence([.group([.scale(to: 1, duration: 0.3), .fadeOut(withDuration: 0.35)]),
                              .removeFromParent()]))
        for i in 0..<9 {
            let crumb = NotebookVisuals.card(CGSize(width: 6, height: 3), radius: 1)
            crumb.position = hero.position
            crumb.zPosition = 4001
            addChild(crumb)
            let a = CGFloat(i) * 0.7
            crumb.run(.sequence([.group([.moveBy(x: cos(a) * 70, y: sin(a) * 70, duration: 0.4),
                                        .fadeOut(withDuration: 0.4)]), .removeFromParent()]))
        }
    }
}
