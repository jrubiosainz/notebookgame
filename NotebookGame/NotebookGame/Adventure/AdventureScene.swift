import SpriteKit
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// One continuous world: no encounter screen, no damage numbers, only erasure.
final class AdventureScene: SKScene {
    let engine: AdventureEngine
    var savesEnabled = true
    var saveHandler: (AdventureSave) throws -> Void = { try AdventureStore.save($0) }
    #if DEBUG
    var capturePanel: String?
    #endif
    private let world = AdventureWorldNode()
    private let interface = SKNode()
    private let modal = SKNode()
    private let night = SKSpriteNode()
    private let joystick = SKNode()
    private let knob = SKShapeNode(circleOfRadius: 20)
    private var buttons: [NotebookButton] = []
    private var modalButtons: [NotebookButton] = []
    private var labels: [String: SKLabelNode] = [:]
    private var meters: [String: SKShapeNode] = [:]
    private let palette = SKNode()
    private let minimap = SKNode()
    private var paletteColors: Set<Pigment> = []
    private var lastTime: TimeInterval = 0
    private var hudClock: Double = 0
    private var saveClock: Double = 0
    private var movement = CGVector.zero
    private var stickOrigin = CGPoint.zero
    private var selectedBuild: BuildKind?
    private var modalKind: String?
    private var dialogueLines: [String] = []
    private var dialogueTitle = ""
    private var dialogueIndex = 0
    private var introIndex = 0
    private var journalPage = 0
    private var lastToast = ""
    private var saveErrorShown = false
    private var isSuspended = false
    private var observationTokens: [NSObjectProtocol] = []
    #if canImport(UIKit)
    private var stickTouch: UITouch?
    #else
    private var mouseStick = false
    private var keys: Set<UInt16> = []
    #endif

    init(size: CGSize, engine: AdventureEngine = AdventureEngine()) {
        self.engine = engine
        super.init(size: size)
        scaleMode = .resizeFill
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    private var safeTop: CGFloat {
        #if canImport(UIKit)
        return max(14, view?.safeAreaInsets.top ?? 14)
        #else
        return 34
        #endif
    }

    private var safeBottom: CGFloat {
        #if canImport(UIKit)
        return max(12, view?.safeAreaInsets.bottom ?? 12)
        #else
        return 22
        #endif
    }

    override func didMove(to view: SKView) {
        backgroundColor = NotebookVisuals.paper
        addChild(world)
        world.rebuild(engine)
        night.zPosition = 5000
        addChild(night)
        interface.zPosition = 10000
        addChild(interface)
        modal.zPosition = 20000
        addChild(modal)
        buildInterface()
        updateCamera(immediate: true)
        refreshHUD()
        refreshLighting()
        night.alpha = engine.isNight ? 1 : 0
        if !engine.save.introSeen { showIntro() }
        #if DEBUG
        if let capturePanel { perform(capturePanel) }
        #endif
        #if canImport(UIKit)
        view.isMultipleTouchEnabled = true
        observe(UIApplication.willResignActiveNotification) { [weak self] in self?.suspend() }
        observe(UIApplication.didBecomeActiveNotification) { [weak self] in self?.resume() }
        #else
        observe(NSApplication.willResignActiveNotification) { [weak self] in self?.suspend() }
        observe(NSApplication.didBecomeActiveNotification) { [weak self] in self?.resume() }
        #endif
    }

    private func observe(_ name: Notification.Name, action: @escaping () -> Void) {
        observationTokens.append(NotificationCenter.default.addObserver(forName: name, object: nil,
                                                                        queue: .main) { _ in action() })
    }

    deinit {
        for token in observationTokens { NotificationCenter.default.removeObserver(token) }
    }

    override func willMove(from view: SKView) { persist() }

    override func didChangeSize(_ oldSize: CGSize) {
        guard interface.parent != nil else { return }
        buildInterface()
        refreshHUD()
        updateCamera(immediate: true)
        if modalKind != nil { renderModal() }
    }

    private func suspend() {
        isSuspended = true
        resetInput()
        persist()
    }

    private func resume() {
        isSuspended = false
        lastTime = 0
    }

    @discardableResult
    func persist() -> Bool {
        guard savesEnabled else { return true }
        do {
            try saveHandler(engine.save)
            saveErrorShown = false
            return true
        } catch {
            if !saveErrorShown {
                showToast("No se pudo guardar. Conserva el juego abierto.")
                saveErrorShown = true
            }
            NSLog("Adventure save failed: %@", error.localizedDescription)
            return false
        }
    }

    private func addLabel(_ key: String, _ text: String, x: CGFloat, y: CGFloat,
                          fontSize: CGFloat = 14, color: SKColor = NotebookVisuals.ink,
                          sans: Bool = false, parent: SKNode? = nil) -> SKLabelNode {
        let label = NotebookVisuals.label(text, size: fontSize, color: color, sans: sans)
        label.position = CGPoint(x: x, y: y)
        (parent ?? interface).addChild(label)
        labels[key] = label
        return label
    }

    private func addButton(_ title: String, id: String, x: CGFloat, y: CGFloat,
                           width: CGFloat, height: CGFloat = 46, filled: Bool = false,
                           modal isModal: Bool = false, font: CGFloat = 13) {
        let button = NotebookButton(title, id: id, width: width, height: height,
                                    filled: filled, fontSize: font)
        button.position = CGPoint(x: x, y: y)
        if isModal { modal.addChild(button); modalButtons.append(button) }
        else { interface.addChild(button); buttons.append(button) }
    }

    private func buildInterface() {
        interface.removeAllChildren()
        buttons.removeAll()
        labels.removeAll()
        meters.removeAll()
        palette.removeAllChildren()
        minimap.removeAllChildren()
        paletteColors = []
        let w = size.width
        let top = size.height - safeTop
        let header = NotebookVisuals.card(CGSize(width: w + 4, height: safeTop + 150), radius: 0)
        header.position = CGPoint(x: w / 2, y: size.height - (safeTop + 150) / 2)
        header.strokeColor = NotebookVisuals.muted.withAlphaComponent(0.28)
        interface.addChild(header)
        _ = addLabel("brand", "N O T E B O O K", x: 23, y: top - 10, fontSize: 11,
                     color: NotebookVisuals.muted, sans: true).horizontalAlignmentMode = .left
        _ = addLabel("page", engine.page.name, x: 22, y: top - 36, fontSize: 21).horizontalAlignmentMode = .left
        addButton("DIARIO", id: "journal", x: w - 52, y: top - 23, width: 74, height: 44, font: 11)
        let rule = NotebookVisuals.rule(width: w - 44, color: NotebookVisuals.muted.withAlphaComponent(0.4))
        rule.position = CGPoint(x: w / 2, y: top - 57)
        interface.addChild(rule)
        let usable = w - 120
        for (index, key) in ["integrity", "hunger", "warmth"].enumerated() {
            let x = 22 + CGFloat(index) * usable / 3
            let titles = ["TRAZO", "COMIDA", "CALOR"]
            let title = addLabel(key + "Label", titles[index], x: x, y: top - 72,
                                 fontSize: 9, color: NotebookVisuals.muted, sans: true)
            title.horizontalAlignmentMode = .left
            let bg = NotebookVisuals.card(CGSize(width: usable / 3 - 13, height: 5),
                                          fill: SKColor(white: 0.80, alpha: 0.6), radius: 2)
            bg.lineWidth = 0
            bg.position = CGPoint(x: x + (usable / 3 - 13) / 2, y: top - 86)
            interface.addChild(bg)
            let fill = SKShapeNode(rect: CGRect(x: 0, y: -2.5, width: usable / 3 - 13, height: 5),
                                   cornerRadius: 2)
            fill.strokeColor = .clear
            fill.fillColor = [NotebookVisuals.color(.red), NotebookVisuals.color(.green), NotebookVisuals.gold][index]
            fill.position = CGPoint(x: x, y: top - 86)
            interface.addChild(fill)
            meters[key] = fill
        }
        _ = addLabel("time", "", x: w - 49, y: top - 72, fontSize: 12, sans: true)
        _ = addLabel("day", "", x: w - 49, y: top - 89, fontSize: 10, color: NotebookVisuals.muted)
        let objective = addLabel("objective", "", x: 22, y: top - 119, fontSize: 12)
        objective.horizontalAlignmentMode = .left
        objective.numberOfLines = 2
        objective.preferredMaxLayoutWidth = w - 44
        objective.lineBreakMode = .byWordWrapping

        palette.position = CGPoint(x: 24, y: top - 175)
        interface.addChild(palette)
        minimap.position = CGPoint(x: w - 57, y: top - 210)
        interface.addChild(minimap)

        let bottom = safeBottom
        let footer = NotebookVisuals.card(CGSize(width: w + 4, height: bottom + 183), radius: 0)
        footer.position = CGPoint(x: w / 2, y: (bottom + 183) / 2)
        footer.fillColor = NotebookVisuals.paper.withAlphaComponent(0.97)
        footer.strokeColor = NotebookVisuals.muted.withAlphaComponent(0.28)
        interface.addChild(footer)
        _ = addLabel("resources", "", x: 22, y: bottom + 163, fontSize: 11,
                     color: NotebookVisuals.muted, sans: true).horizontalAlignmentMode = .left
        _ = addLabel("depth", "", x: w - 20, y: bottom + 163, fontSize: 9,
                     color: NotebookVisuals.muted, sans: true).horizontalAlignmentMode = .right
        let toolWidth = (w - 48) / 3
        addButton("CONSTRUIR", id: "craft", x: 16 + toolWidth / 2, y: bottom + 128,
                  width: toolWidth, height: 44, font: 10)
        addButton("COMER", id: "eat", x: w / 2, y: bottom + 128, width: toolWidth, height: 44, font: 10)
        addButton("DESCANSAR", id: "rest", x: w - 16 - toolWidth / 2, y: bottom + 128,
                  width: toolWidth, height: 44, font: 10)
        joystick.removeAllChildren()
        joystick.position = CGPoint(x: 84, y: bottom + 63)
        let ring = SKShapeNode(circleOfRadius: 44)
        ring.fillColor = NotebookVisuals.paper
        ring.strokeColor = NotebookVisuals.muted.withAlphaComponent(0.5)
        ring.lineWidth = 1.3
        joystick.addChild(ring)
        let inner = SKShapeNode(circleOfRadius: 35)
        inner.fillColor = .clear
        inner.strokeColor = NotebookVisuals.muted.withAlphaComponent(0.15)
        inner.lineWidth = 1
        joystick.addChild(inner)
        knob.fillColor = NotebookVisuals.ink.withAlphaComponent(0.13)
        knob.strokeColor = NotebookVisuals.ink.withAlphaComponent(0.45)
        knob.lineWidth = 1.2
        knob.position = .zero
        joystick.addChild(knob)
        interface.addChild(joystick)
        _ = addLabel("walk", "MOVER", x: 84, y: bottom + 8, fontSize: 9,
                     color: NotebookVisuals.muted, sans: true)
        addButton("BORRAR", id: "erase", x: w - 182, y: bottom + 58, width: 83, height: 57, font: 11)
        addButton("EXPLORAR", id: "interact", x: w - 70, y: bottom + 58,
                  width: 124, height: 57, filled: true, font: 12)
        _ = addLabel("target", "", x: w - 125, y: bottom + 14, fontSize: 10, color: NotebookVisuals.muted)
        night.size = size
        night.position = CGPoint(x: w / 2, y: size.height / 2)
        resetInput()
    }

    private func refreshHUD() {
        labels["page"]?.text = engine.page.name
        if let label = labels["page"] {
            label.fontSize = 21
            label.fontSize = min(21, 21 * (size.width - 120) / max(1, label.frame.width))
        }
        labels["objective"]?.text = engine.objective
        labels["time"]?.text = engine.isNight ? "NOCHE" : "LUZ"
        labels["day"]?.text = "DIA \(engine.day)"
        labels["resources"]?.text = "\(engine.save.scraps) PAPEL   \(engine.save.wood) MADERA   \(engine.save.food) BAYAS"
        labels["depth"]?.text = engine.page.depth == 0
            ? "P. \(engine.page.number) / SUP." : "P. \(engine.page.number) / -\(engine.page.depth)"
        meters["integrity"]?.xScale = max(0.001, CGFloat(engine.save.integrity / 100))
        meters["hunger"]?.xScale = max(0.001, CGFloat(engine.save.hunger / 100))
        meters["warmth"]?.xScale = max(0.001, CGFloat(engine.save.warmth / 100))
        let nearby = engine.nearbyObject
        buttons.first { $0.actionID == "interact" }?.caption.text = selectedBuild != nil
            ? "COLOCAR" : nearby.map { engine.prompt(for: $0).uppercased() } ?? "EXPLORAR"
        if let button = buttons.first(where: { $0.actionID == "interact" }) {
            button.caption.fontSize = 12
            if button.caption.frame.width > 110 {
                button.caption.fontSize = max(9, 12 * 110 / button.caption.frame.width)
            }
        }
        labels["target"]?.text = selectedBuild.map { $0.title } ?? nearby?.name ?? "Acercate a un dibujo"
        if let target = labels["target"], target.frame.width > size.width - 145 {
            target.fontSize = 9
        }
        if palette.children.isEmpty || paletteColors != engine.save.colors {
            paletteColors = engine.save.colors
            palette.removeAllChildren()
            for (index, pigment) in Pigment.allCases.enumerated() {
                let known = engine.save.colors.contains(pigment)
                let dot = NotebookVisuals.wash(radius: 12,
                                               color: known ? NotebookVisuals.color(pigment)
                                               : NotebookVisuals.paper)
                dot.strokeColor = known ? NotebookVisuals.color(pigment) : NotebookVisuals.muted.withAlphaComponent(0.5)
                dot.lineWidth = 1
                dot.position = CGPoint(x: CGFloat(index) * 29, y: 0)
                palette.addChild(dot)
                let marker = NotebookVisuals.label(known ? String(pigment.title.prefix(1)) : "?", size: 9,
                                                   color: known ? NotebookVisuals.paper : NotebookVisuals.muted,
                                                   sans: true)
                dot.addChild(marker)
            }
        }
        drawMinimap()
    }

    private func drawMinimap() {
        minimap.removeAllChildren()
        let bg = NotebookVisuals.card(CGSize(width: 79, height: 93), radius: 5)
        bg.fillColor = NotebookVisuals.paper.withAlphaComponent(0.90)
        bg.strokeColor = NotebookVisuals.muted.withAlphaComponent(0.4)
        minimap.addChild(bg)
        let scale: CGFloat = 2.4
        let origin = CGPoint(x: -CGFloat(engine.page.width) * scale / 2,
                             y: -CGFloat(engine.page.height) * scale / 2 + 6)
        for point in engine.inkTiles {
            let dot = SKSpriteNode(color: NotebookVisuals.ink.withAlphaComponent(0.65),
                                   size: CGSize(width: scale + 0.5, height: scale + 0.5))
            dot.position = CGPoint(x: origin.x + CGFloat(point.x) * scale,
                                   y: origin.y + CGFloat(point.y) * scale)
            minimap.addChild(dot)
        }
        for object in engine.page.objects where engine.isAvailable(object) {
            guard [.gate, .pigment, .npc, .memory, .inkwell].contains(object.kind) else { continue }
            let marker = SKShapeNode(circleOfRadius: object.kind == .gate ? 2.2 : 1.5)
            marker.fillColor = object.pigment.map(NotebookVisuals.color) ?? NotebookVisuals.muted
            marker.strokeColor = .clear
            marker.position = CGPoint(x: origin.x + CGFloat(object.point.x) * scale,
                                      y: origin.y + CGFloat(object.point.y) * scale)
            minimap.addChild(marker)
        }
        let hero = SKShapeNode(circleOfRadius: 2.7)
        hero.fillColor = NotebookVisuals.color(.red)
        hero.strokeColor = NotebookVisuals.paper
        hero.lineWidth = 1
        hero.position = CGPoint(x: origin.x + CGFloat(engine.save.x) * scale,
                                y: origin.y + CGFloat(engine.save.y) * scale)
        minimap.addChild(hero)
        let title = NotebookVisuals.label("PAGINA \(engine.page.number)", size: 8, sans: true)
        title.position.y = -36
        minimap.addChild(title)
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = lastTime == 0 ? 0 : min(0.05, max(0, currentTime - lastTime))
        lastTime = currentTime
        guard !isSuspended, modalKind == nil else { return }
        #if !canImport(UIKit)
        if !keys.isEmpty {
            movement = CGVector(dx: (keys.contains(2) || keys.contains(124) ? 1 : 0)
                                - (keys.contains(0) || keys.contains(123) ? 1 : 0),
                                dy: (keys.contains(13) || keys.contains(126) ? 1 : 0)
                                - (keys.contains(1) || keys.contains(125) ? 1 : 0))
        }
        #endif
        let length = max(1, hypot(movement.dx, movement.dy))
        _ = engine.move(dx: Double(movement.dx / length) * dt * 3.1,
                        dy: Double(movement.dy / length) * dt * 3.1)
        let oldPage = engine.save.pageID
        engine.tick(dt)
        if oldPage != engine.save.pageID { world.rebuild(engine); updateCamera(immediate: true) }
        world.refresh(engine, dt: dt, buildMode: selectedBuild)
        updateCamera(immediate: false)
        night.alpha += ((engine.isNight ? 1 : 0) - night.alpha) * CGFloat(dt) * 2
        hudClock += dt
        saveClock += dt
        if hudClock > 0.20 {
            hudClock = 0
            refreshHUD()
            refreshLighting()
        }
        if saveClock > 5 {
            saveClock = 0
            persist()
        }
        if let message = engine.lastMessage, message != lastToast {
            lastToast = message
            showToast(message)
        }
    }

    private func refreshLighting() {
        guard engine.isNight || night.alpha > 0.01 else { return }
        var lights: [(CGPoint, CGFloat)] = [
            (AdventureWorldNode.position(x: engine.save.x, y: engine.save.y), 103)
        ]
        for build in engine.save.builds where build.pageID == engine.page.id {
            if build.kind == .campfire, build.fuel > 0 {
                lights.append((AdventureWorldNode.position(build.point), 230))
            } else if build.kind == .shelter {
                lights.append((AdventureWorldNode.position(build.point), 80))
            }
        }
        night.texture = NotebookVisuals.nightTexture(size: size, lights: lights.map {
            (CGPoint(x: $0.0.x + world.position.x, y: $0.0.y + world.position.y), $0.1)
        })
    }

    private func updateCamera(immediate: Bool) {
        let hero = AdventureWorldNode.position(x: engine.save.x, y: engine.save.y)
        let desired = CGPoint(x: size.width / 2 - hero.x, y: size.height * 0.49 - hero.y)
        if immediate { world.position = desired } else {
            world.position.x += (desired.x - world.position.x) * 0.18
            world.position.y += (desired.y - world.position.y) * 0.18
        }
    }

    /// Shared entry point for touch controls, desktop preview and regression playback.
    func perform(_ id: String) {
        if modalKind != nil, !modalButtons.contains(where: { $0.actionID == id }) { return }
        NotebookVisuals.tapFeedback()
        switch id {
        case "intro-next":
            introIndex += 1
            if introIndex >= Self.opening.count {
                engine.markIntroSeen()
                closeModal()
                persist()
                showToast("Busca el pigmento marron. El diario te guiara.")
            } else { showIntro() }
        case "intro-skip":
            engine.markIntroSeen()
            closeModal()
            persist()
        case "close":
            closeModal()
        case "next-line":
            dialogueIndex += 1
            if dialogueIndex >= dialogueLines.count { closeModal() } else { renderDialogue() }
        case "journal":
            journalPage = 0
            openModal("journal")
        case "journal-next":
            journalPage = (journalPage + 1) % (journalSheets.count + 1)
            renderJournal()
        case "craft":
            openModal("craft")
        case "eat":
            consume(engine.eat())
        case "rest":
            consume(engine.rest())
        case "erase":
            guard modalKind == nil else { return }
            let result = engine.erase()
            if result.success { world.eraseEffect(reach: engine.eraserReach) }
            consume(result, asDialogue: false)
        case "interact":
            guard modalKind == nil else { return }
            if let kind = selectedBuild {
                let result = engine.build(kind, at: engine.targetPoint)
                if result.success, kind != .wall, kind != .path { selectedBuild = nil }
                consume(result)
            } else if let object = engine.nearbyObject {
                let result = engine.interact(object.id)
                if let color = result.color, result.success {
                    world.paintEffect(at: object.point, pigment: color)
                }
                consume(result, asDialogue: object.kind == .npc || object.kind == .memory || object.kind == .inkwell)
            } else {
                showToast("Los puntos del mapa son dibujos por descubrir.")
            }
        case "cancel-build":
            selectedBuild = nil
            closeModal()
        case "cover":
            guard persist() else {
                showToast("No se pudo guardar. Tu aventura sigue abierta; vuelve a intentarlo.")
                return
            }
            view?.presentScene(AdventureCoverScene(size: size), transition: .fade(withDuration: 0.3))
        default:
            if id.hasPrefix("build-"), let kind = BuildKind(rawValue: String(id.dropFirst(6))) {
                selectedBuild = kind
                closeModal()
                showToast("Mira al lugar y pulsa COLOCAR. Verde = valido.")
            }
        }
        world.refresh(engine, dt: 0, buildMode: selectedBuild)
        refreshHUD()
        refreshLighting()
    }

    private func consume(_ event: AdventureEvent, asDialogue: Bool = false) {
        lastToast = engine.lastMessage ?? ""
        if event.changedPage {
            resetInput()
            world.rebuild(engine)
            updateCamera(immediate: true)
            let flash = SKSpriteNode(color: NotebookVisuals.paper, size: size)
            flash.position = CGPoint(x: size.width / 2, y: size.height / 2)
            flash.zPosition = 15000
            addChild(flash)
            flash.run(.sequence([.fadeOut(withDuration: 0.55), .removeFromParent()]))
        }
        if asDialogue && !event.lines.isEmpty {
            dialogueTitle = event.title
            dialogueLines = event.lines
            dialogueIndex = 0
            openModal("dialogue")
        } else {
            let detail = event.lines.filter { $0 != event.title }
            showToast(([event.title] + detail).joined(separator: "  "))
        }
        persist()
    }

    private func showToast(_ text: String) {
        interface.childNode(withName: "toast")?.removeFromParent()
        modal.childNode(withName: "toast")?.removeFromParent()
        let label = NotebookVisuals.text(text, width: size.width - 64, size: 13)
        let height = max(43, min(130, label.frame.height + 24))
        let card = NotebookVisuals.card(CGSize(width: size.width - 36, height: height), radius: 8)
        card.name = "toast"
        card.position = CGPoint(x: size.width / 2, y: safeBottom + 211 + height / 2)
        card.zPosition = 100
        label.zPosition = 1
        card.addChild(label)
        (modalKind == nil ? interface : modal).addChild(card)
        card.run(.sequence([.wait(forDuration: 3.3), .fadeOut(withDuration: 0.3), .removeFromParent()]))
    }

    private func resetInput() {
        movement = .zero
        knob.position = .zero
        #if canImport(UIKit)
        stickTouch = nil
        #else
        mouseStick = false
        keys.removeAll()
        #endif
    }

    private func openModal(_ kind: String) {
        resetInput()
        modalKind = kind
        persist()
        renderModal()
    }

    private func closeModal() {
        modal.removeAllChildren()
        modalButtons.removeAll()
        modalKind = nil
        resetInput()
        lastTime = 0
    }

    private func modalBase(title: String, subtitle: String) -> (top: CGFloat, bottom: CGFloat) {
        modal.removeAllChildren()
        modalButtons.removeAll()
        let shade = SKSpriteNode(color: NotebookVisuals.ink.withAlphaComponent(0.63), size: size)
        shade.position = CGPoint(x: size.width / 2, y: size.height / 2)
        modal.addChild(shade)
        let top = size.height - safeTop - 27
        let bottom = safeBottom + 28
        let card = NotebookVisuals.card(CGSize(width: size.width - 28, height: top - bottom), radius: 13)
        card.position = CGPoint(x: size.width / 2, y: (top + bottom) / 2)
        modal.addChild(card)
        let heading = NotebookVisuals.label(title, size: 28)
        if heading.frame.width > size.width - 70 {
            heading.fontSize *= (size.width - 70) / heading.frame.width
        }
        heading.position = CGPoint(x: size.width / 2, y: top - 38)
        modal.addChild(heading)
        let sub = NotebookVisuals.label(subtitle, size: 10, color: NotebookVisuals.muted, sans: true)
        sub.position = CGPoint(x: size.width / 2, y: top - 70)
        modal.addChild(sub)
        let rule = NotebookVisuals.rule(width: size.width - 76)
        rule.position = CGPoint(x: size.width / 2, y: top - 90)
        modal.addChild(rule)
        return (top, bottom)
    }

    private func renderModal() {
        switch modalKind {
        case "intro": showIntro()
        case "craft": renderCraft()
        case "journal": renderJournal()
        case "dialogue": renderDialogue()
        default: break
        }
    }

    private static let opening: [(title: String, body: String, art: String, folder: String)] = [
        ("Antes del desborde",
         "Alguien cerro el cuaderno antes de terminar su historia.\n\nEn el margen, Nib siguio esperando la siguiente palabra.",
         "old_inkwell", "npcs"),
        ("La tinta desperto",
         "Una grieta en el tintero. Una mancha sin dueno.\n\nLa tinta escapo de sus lineas y empezo a cubrir paginas, caminos y recuerdos.",
         "big_smudge", "enemies"),
        ("No todo esta escrito",
         "Los dibujos perdieron su color. Un cofre sin marron ya no sabia abrirse. Un arbol sin verde olvido crecer.\n\nPero Nib encontro una goma. Y una ultima gota de color.",
         "nib_idle", "characters"),
        ("Devuelve el color",
         "Pinta para despertar las cosas. Borra a las criaturas de tinta. Construye donde ya no quede suelo.\n\nY cuando llegue la noche, recuerda: rojo y amarillo hacen un hogar de luz.",
         "campfire", "props")
    ]

    private func showIntro() {
        modalKind = "intro"
        resetInput()
        let entry = Self.opening[min(introIndex, Self.opening.count - 1)]
        let bounds = modalBase(title: entry.title, subtitle: "EL DESBORDE  /  PROLOGO \(introIndex + 1) DE 4")
        let available = bounds.top - bounds.bottom
        let wash = NotebookVisuals.wash(radius: min(120, size.width * 0.28),
                                        color: (introIndex == 1 ? NotebookVisuals.ink : NotebookVisuals.gold)
                                            .withAlphaComponent(introIndex == 1 ? 0.15 : 0.09))
        wash.position = CGPoint(x: size.width / 2, y: bounds.top - available * 0.34)
        modal.addChild(wash)
        let illustration = NotebookVisuals.sprite(entry.art, folder: entry.folder,
                                                  height: min(190, available * 0.27))
        illustration.position = wash.position
        if introIndex == 3 {
            illustration.color = NotebookVisuals.color(.yellow)
            illustration.colorBlendFactor = 0.6
        }
        modal.addChild(illustration)
        illustration.run(.repeatForever(.sequence([.moveBy(x: 0, y: 4, duration: 1.6),
                                                    .moveBy(x: 0, y: -4, duration: 1.6)])))
        let text = NotebookVisuals.text(entry.body, width: size.width - 86, size: 17)
        let textTop = bounds.top - available * 0.52
        let textBottom = bounds.bottom + 113
        while text.frame.height > textTop - textBottom && text.fontSize > 12 {
            text.fontSize -= 0.5
        }
        text.position = CGPoint(x: size.width / 2, y: (textTop + textBottom) / 2)
        modal.addChild(text)
        addButton(introIndex == 3 ? "ABRIR EL CUADERNO" : "PASAR PAGINA", id: "intro-next",
                  x: size.width / 2, y: bounds.bottom + 74, width: size.width - 92,
                  height: 49, filled: true, modal: true)
        addButton("SALTAR PROLOGO", id: "intro-skip", x: size.width / 2,
                  y: bounds.bottom + 28, width: 170, height: 32, modal: true, font: 10)
    }

    private func renderDialogue() {
        let bounds = modalBase(title: dialogueTitle, subtitle: "VOCES ENTRE LOS RENGLONES")
        let text = NotebookVisuals.text(dialogueLines[dialogueIndex], width: size.width - 86, size: 21)
        text.position = CGPoint(x: size.width / 2, y: (bounds.top + bounds.bottom) / 2)
        modal.addChild(text)
        let marker = NotebookVisuals.label("\(dialogueIndex + 1) / \(dialogueLines.count)", size: 11,
                                           color: NotebookVisuals.muted, sans: true)
        marker.position = CGPoint(x: size.width / 2, y: bounds.bottom + 108)
        modal.addChild(marker)
        addButton(dialogueIndex == dialogueLines.count - 1 ? "VOLVER AL MARGEN" : "SEGUIR LEYENDO",
                  id: "next-line", x: size.width / 2, y: bounds.bottom + 62,
                  width: size.width - 90, height: 49, filled: true, modal: true)
    }

    private func renderCraft() {
        let bounds = modalBase(title: "La mesa de Nib", subtitle: "PIEZAS SUELTAS, NUEVOS CAMINOS")
        let descriptions: [BuildKind: String] = [
            .path: "Papel sobre tinta. Un paso donde antes no habia suelo.",
            .wall: "Madera que contiene el avance de la mancha.",
            .campfire: "Rojo + amarillo. Luz, calor y tinta a distancia.",
            .shelter: "Un refugio verde. Descansa y guarda tu regreso."
        ]
        let rowHeight = min(121, (bounds.top - bounds.bottom - 245) / 4)
        for (index, kind) in BuildKind.allCases.enumerated() {
            let y = bounds.top - 110 - CGFloat(index) * rowHeight
            let title = NotebookVisuals.label(kind.title, size: 18)
            title.horizontalAlignmentMode = .left
            title.position = CGPoint(x: 37, y: y - 8)
            modal.addChild(title)
            let desc = NotebookVisuals.text(descriptions[kind] ?? "", width: size.width - 92,
                                            size: size.height < 750 ? 10 : 12,
                                            color: NotebookVisuals.muted)
            desc.horizontalAlignmentMode = .left
            desc.position = CGPoint(x: 37, y: y - 35)
            modal.addChild(desc)
            let recipe = NotebookVisuals.label(engine.buildRequirement(kind), size: 10,
                                               color: NotebookVisuals.blue, sans: true)
            recipe.horizontalAlignmentMode = .left
            recipe.position = CGPoint(x: 37, y: y - rowHeight + 25)
            modal.addChild(recipe)
            addButton("ELEGIR", id: "build-" + kind.rawValue, x: size.width - 78, y: y - 5,
                      width: 83, height: 36, modal: true, font: 10)
            let rule = NotebookVisuals.rule(width: size.width - 76, color: NotebookVisuals.muted.withAlphaComponent(0.3))
            rule.position = CGPoint(x: size.width / 2, y: y - rowHeight + 10)
            modal.addChild(rule)
        }
        let hint = NotebookVisuals.text("Elige una receta, orienta a Nib y coloca la pieza en el recuadro verde.",
                                        width: size.width - 82, size: 12, color: NotebookVisuals.muted)
        hint.position = CGPoint(x: size.width / 2, y: bounds.bottom + 94)
        modal.addChild(hint)
        addButton(selectedBuild == nil ? "VOLVER" : "CANCELAR CONSTRUCCION",
                  id: "cancel-build", x: size.width / 2, y: bounds.bottom + 44,
                  width: size.width - 88, modal: true)
    }

    private var journalSheets: [(String, String)] {
        let techniques = [
            "MOVER / Explora con el pulgar izquierdo.",
            "PINTAR / Encuentra un pigmento y acercate a un dibujo gris. Pinta primero; usalo despues.",
            "BORRAR / La goma desvanece criaturas y abre espacio en la tinta. Los recuerdos mejoran su alcance.",
            "CONSTRUIR / El recuadro mira hacia donde andas. Los caminos cruzan tinta; los muros la contienen. Abre la mesa para cancelar.",
            "SOBREVIVIR / Come bayas. Combina rojo y amarillo para el fuego. Acercate y pulsa DESCANSAR para echar lena.",
            "DESCANSAR / Cerca de tu refugio recuperas fuerzas. La noche no avanza mientras lees."
        ]
        let availableHeight = size.height - safeTop - safeBottom - 310
        var sheets: [(String, String)] = []
        for (subtitle, entries) in [("LO QUE RECUERDA EL PAPEL", [engine.objective] + engine.journal),
                                    ("TECNICAS DEL MARGEN", techniques)] {
            var content = ""
            for entry in entries {
                let candidate = content.isEmpty ? entry : content + "\n\n" + entry
                let label = NotebookVisuals.text(candidate, width: size.width - 83, size: 14)
                if label.frame.height > availableHeight && !content.isEmpty {
                    sheets.append((subtitle, content))
                    content = entry
                } else { content = candidate }
            }
            if !content.isEmpty { sheets.append((subtitle, content)) }
        }
        return sheets
    }

    private func renderJournal() {
        let sheets = journalSheets
        journalPage = min(journalPage, sheets.count)
        let bounds = modalBase(title: "Diario de Nib", subtitle: journalPage == 0
                               ? "ATLAS DE UN CUADERNO HERIDO" : sheets[journalPage - 1].0)
        if journalPage == 0 {
            drawAtlas(top: bounds.top, bottom: bounds.bottom)
        } else {
            let content = NotebookVisuals.text(sheets[journalPage - 1].1, width: size.width - 83, size: 14)
            content.verticalAlignmentMode = .top
            content.position = CGPoint(x: size.width / 2, y: bounds.top - 112)
            modal.addChild(content)
        }
        addButton("HOJA \(journalPage + 1)/\(sheets.count + 1)  >", id: "journal-next", x: size.width * 0.34,
                  y: bounds.bottom + 75, width: size.width * 0.43, height: 44, modal: true, font: 11)
        addButton("CERRAR", id: "close", x: size.width * 0.76, y: bounds.bottom + 75,
                  width: size.width * 0.28, height: 44, filled: true, modal: true, font: 11)
        addButton("GUARDAR Y SALIR", id: "cover", x: size.width / 2,
                  y: bounds.bottom + 27, width: size.width - 100, height: 34, modal: true, font: 10)
    }

    private func drawAtlas(top: CGFloat, bottom: CGFloat) {
        let pages = AdventureCatalog.pages
        let rowGap = min(118, (top - bottom - 245) / 3)
        let centerX = size.width / 2
        for depth in 0..<3 {
            let y = top - 161 - CGFloat(depth) * rowGap
            let rule = NotebookVisuals.rule(width: size.width - 84, color: NotebookVisuals.muted.withAlphaComponent(0.25))
            rule.position = CGPoint(x: centerX, y: y)
            modal.addChild(rule)
            let depthLabel = NotebookVisuals.label(depth == 0 ? "SUPERFICIE" : "PROFUNDIDAD -\(depth)",
                                                   size: 9, color: NotebookVisuals.muted, sans: true)
            depthLabel.position = CGPoint(x: centerX, y: y + 51)
            modal.addChild(depthLabel)
        }
        var positions: [String: CGPoint] = [:]
        for (i, page) in pages.enumerated() {
            positions[page.id] = CGPoint(x: size.width * (i % 2 == 0 ? 0.29 : 0.71),
                                         y: top - 161 - CGFloat(page.depth) * rowGap)
        }
        for page in pages {
            for gate in page.objects where gate.kind == .gate {
                guard let from = positions[page.id], let target = gate.targetPage, let to = positions[target] else { continue }
                let path = CGMutablePath()
                path.move(to: from)
                path.addLine(to: to)
                let link = SKShapeNode(path: path)
                link.strokeColor = gate.pigment.map(NotebookVisuals.color) ?? NotebookVisuals.muted
                link.alpha = engine.save.visited.contains(page.id) ? 0.6 : 0.17
                link.lineWidth = 1.5
                modal.addChild(link)
            }
        }
        for page in pages {
            guard let point = positions[page.id] else { continue }
            let visited = engine.save.visited.contains(page.id)
            let tile = NotebookVisuals.card(CGSize(width: size.width * 0.33, height: 62),
                                            fill: page.id == engine.page.id ? NotebookVisuals.ink : NotebookVisuals.paper,
                                            radius: 7)
            tile.position = point
            modal.addChild(tile)
            let title = NotebookVisuals.text(visited ? page.name : "Pagina sin abrir",
                                             width: size.width * 0.29, size: 12,
                                             color: page.id == engine.page.id ? NotebookVisuals.paper : NotebookVisuals.ink)
            title.position.y = 4
            tile.addChild(title)
            let number = NotebookVisuals.label("0\(page.number)", size: 9, color: NotebookVisuals.gold, sans: true)
            number.position = CGPoint(x: 0, y: -22)
            tile.addChild(number)
        }
        let hint = NotebookVisuals.text("El color abre rutas. Los tuneles y puentes permiten volver a las paginas anteriores.",
                                        width: size.width - 82, size: 12, color: NotebookVisuals.muted)
        hint.position = CGPoint(x: centerX, y: bottom + 143)
        modal.addChild(hint)
    }

    private func routePress(_ point: CGPoint) -> Bool {
        if modalKind != nil {
            if let button = modalButtons.reversed().first(where: { $0.hit(point, in: self) }) {
                perform(button.actionID)
            }
            return true
        }
        if let button = buttons.reversed().first(where: { $0.hit(point, in: self) }) {
            perform(button.actionID)
            return true
        }
        return false
    }

    private func updateStick(_ point: CGPoint) {
        let dx = point.x - stickOrigin.x
        let dy = point.y - stickOrigin.y
        let distance = hypot(dx, dy)
        let scale = min(1, 44 / max(1, distance))
        knob.position = CGPoint(x: dx * scale, y: dy * scale)
        movement = distance < 7 ? .zero : CGVector(dx: dx * scale / 44, dy: dy * scale / 44)
    }

    #if canImport(UIKit)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let point = touch.location(in: self)
            if routePress(point) { continue }
            if point.x < size.width * 0.48, point.y < size.height * 0.48, stickTouch == nil {
                stickTouch = touch
                stickOrigin = point
                updateStick(point)
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches where touch === stickTouch { updateStick(touch.location(in: self)) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches where touch === stickTouch { resetInput() }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }
    #else
    override func mouseDown(with event: NSEvent) {
        let point = event.location(in: self)
        if routePress(point) { return }
        if point.x < size.width * 0.48, point.y < size.height * 0.48 {
            mouseStick = true
            stickOrigin = point
            updateStick(point)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        if mouseStick { updateStick(event.location(in: self)) }
    }

    override func mouseUp(with event: NSEvent) { resetInput() }

    override func keyDown(with event: NSEvent) {
        if event.isARepeat { return }
        switch event.keyCode {
        case 49: perform("erase")
        case 14: perform("interact")
        case 8: perform("craft")
        case 38: perform("journal")
        case 53:
            if modalKind != "intro", modalKind != "dialogue" { closeModal() }
        default: keys.insert(event.keyCode)
        }
    }

    override func keyUp(with event: NSEvent) {
        keys.remove(event.keyCode)
        if keys.isEmpty { movement = .zero }
    }
    #endif
}
