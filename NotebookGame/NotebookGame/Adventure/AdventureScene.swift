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
    private let knob = NotebookVisuals.sprite("joystick_knob", folder: "ui", height: 44)
    private var buttons: [NotebookButton] = []
    private var modalButtons: [NotebookButton] = []
    private var labels: [String: SKLabelNode] = [:]
    private var hearts: [SKSpriteNode] = []
    private let palette = SKNode()
    private var paletteColors: Set<Pigment> = []
    private var lastTime: TimeInterval = 0
    private var hudClock: Double = 0
    private var saveClock: Double = 0
    private var movement = CGVector.zero
    private var stickOrigin = CGPoint.zero
    private var stickHome = CGPoint.zero
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
        interface.name = "adventure-hud"
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
        hearts.removeAll()
        palette.removeAllChildren()
        paletteColors = []
        let w = size.width
        let top = size.height - safeTop
        for index in 0..<4 {
            let heart = NotebookVisuals.sprite("heart_full", folder: "ui", height: 21)
            heart.size = CGSize(width: 21, height: 21)
            heart.position = CGPoint(x: 27 + CGFloat(index) * 23, y: top - 15)
            interface.addChild(heart)
            hearts.append(heart)
        }
        let food = NotebookVisuals.sprite("bush", height: 22)
        food.position = CGPoint(x: 130, y: top - 15)
        interface.addChild(food)
        _ = addLabel("food", "", x: 151, y: top - 15, fontSize: 13)
        let fire = NotebookVisuals.sprite("campfire", height: 23)
        fire.position = CGPoint(x: 184, y: top - 15)
        interface.addChild(fire)
        _ = addLabel("warmth", "", x: 207, y: top - 15, fontSize: 13)
        _ = addLabel("time", "", x: 21, y: top - 42, fontSize: 12).horizontalAlignmentMode = .left
        addButton("BOLSA", id: "bag", x: w - 49, y: top - 20, width: 81, height: 51, font: 13)
        let page = addLabel("page", engine.page.name, x: w / 2, y: top - 100, fontSize: 17)
        page.run(.sequence([.wait(forDuration: 5), .fadeOut(withDuration: 1.5)]))
        palette.position = CGPoint(x: 26, y: top - 67)
        interface.addChild(palette)
        let bottom = safeBottom
        joystick.removeAllChildren()
        stickHome = CGPoint(x: 79, y: bottom + 70)
        joystick.position = stickHome
        let base = NotebookVisuals.sprite("joystick_base", folder: "ui", height: 110)
        base.name = "original-joystick-base"
        base.alpha = 0.62
        joystick.addChild(base)
        knob.position = .zero
        knob.name = "original-joystick-knob"
        knob.alpha = 0.80
        joystick.addChild(knob)
        interface.addChild(joystick)
        addButton("BORRAR", id: "erase", x: w - 173, y: bottom + 49, width: 83, height: 57, font: 12)
        addButton("MIRAR", id: "interact", x: w - 70, y: bottom + 64,
                  width: 112, height: 72, filled: true, font: 14)
        _ = addLabel("target", "", x: w - 104, y: bottom + 119, fontSize: 11)
        night.size = size
        night.position = CGPoint(x: w / 2, y: size.height / 2)
        resetInput()
    }

    private func refreshHUD() {
        if let label = labels["page"], label.text != engine.page.name {
            label.text = engine.page.name
            label.removeAllActions()
            label.alpha = 1
            label.run(.sequence([.wait(forDuration: 5), .fadeOut(withDuration: 1.5)]))
        }
        labels["time"]?.text = "Dia \(engine.day) / \(engine.isNight ? "noche" : "luz")"
        labels["food"]?.text = "\(Int(ceil(engine.save.hunger)))"
        labels["warmth"]?.text = "\(Int(ceil(engine.save.warmth)))"
        for (index, heart) in hearts.enumerated() {
            heart.texture = NotebookVisuals.texture(engine.save.integrity > Double(index * 25)
                                                    ? "heart_full" : "heart_empty", folder: "ui")
        }
        for label in labels.values {
            label.fontColor = engine.isNight ? NotebookVisuals.paper : NotebookVisuals.ink
        }
        let nearby = engine.nearbyObject
        buttons.first { $0.actionID == "interact" }?.caption.text = selectedBuild != nil
            ? "COLOCAR" : nearby.map(contextCaption) ?? "MIRAR"
        labels["target"]?.text = selectedBuild.map { $0.title } ?? nearby?.name ?? ""
        labels["target"]?.fontSize = 11
        if let target = labels["target"], target.frame.width > 188 {
            target.fontSize *= 188 / target.frame.width
        }
        if palette.children.isEmpty || paletteColors != engine.save.colors {
            paletteColors = engine.save.colors
            palette.removeAllChildren()
            for (index, pigment) in Pigment.allCases.enumerated() {
                let known = engine.save.colors.contains(pigment)
                let dot = NotebookVisuals.wash(radius: 7,
                                               color: known ? NotebookVisuals.color(pigment)
                                               : NotebookVisuals.paper)
                dot.strokeColor = known ? NotebookVisuals.color(pigment) : NotebookVisuals.muted.withAlphaComponent(0.5)
                dot.lineWidth = 1
                dot.position = CGPoint(x: CGFloat(index) * 20, y: 0)
                palette.addChild(dot)
                let marker = NotebookVisuals.label(known ? "" : "?", size: 8,
                                                   color: NotebookVisuals.muted)
                dot.addChild(marker)
            }
        }
    }

    private func contextCaption(_ object: AdventureObject) -> String {
        if object.kind != .pigment, object.pigment != nil, !engine.save.painted.contains(object.id) {
            return "PINTAR"
        }
        switch object.kind {
        case .npc: return "HABLAR"
        case .chest: return "ABRIR"
        case .gate: return "CRUZAR"
        case .memory, .rock: return "LEER"
        case .inkwell: return "RESTAURAR"
        default: return "COGER"
        }
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
        case "bag":
            openModal("bag")
        case "journal-next":
            journalPage = (journalPage + 1) % (journalSheets.count + 1)
            renderJournal()
        case "craft":
            openModal("craft")
        case "eat":
            let event = engine.eat()
            if modalKind == "bag" { renderBag() }
            consume(event)
        case "rest":
            let event = engine.rest()
            if modalKind == "bag" { renderBag() }
            consume(event)
        case "erase":
            guard modalKind == nil else { return }
            let result = engine.erase()
            if result.success { world.eraseEffect(reach: engine.eraserReach, facing: engine.save.facing) }
            consume(result, asDialogue: false)
        case "interact":
            guard modalKind == nil else { return }
            if let kind = selectedBuild {
                let result = engine.build(kind, at: engine.targetPoint)
                if result.success, kind != .wall, kind != .path { selectedBuild = nil }
                consume(result)
            } else if let object = engine.nearbyObject {
                let wasPainted = engine.save.painted.contains(object.id)
                let result = engine.interact(object.id)
                let justPainted = !wasPainted && engine.save.painted.contains(object.id)
                if let color = result.color, result.success {
                    world.paintEffect(at: object.point, pigment: color, animateHero: justPainted)
                }
                consume(result, asDialogue: !justPainted &&
                        (object.kind == .npc || object.kind == .memory || object.kind == .inkwell))
            } else {
                showToast("Acercate a un dibujo. Tu mapa y tus notas estan en la bolsa.")
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
        let card = NotebookVisuals.sprite("menu_panel", folder: "ui", height: height)
        card.size = CGSize(width: size.width - 36, height: height)
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
        joystick.position = stickHome
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
        let wasIntro = modalKind == "intro"
        modal.removeAllChildren()
        modalButtons.removeAll()
        modalKind = nil
        resetInput()
        lastTime = 0
        if wasIntro {
            labels["page"]?.removeAllActions()
            labels["page"]?.alpha = 1
            labels["page"]?.run(.sequence([.wait(forDuration: 5), .fadeOut(withDuration: 1.5)]))
        }
    }

    private func modalBase(title: String, subtitle: String) -> (top: CGFloat, bottom: CGFloat) {
        modal.removeAllChildren()
        modalButtons.removeAll()
        let shade = SKSpriteNode(color: NotebookVisuals.ink.withAlphaComponent(0.63), size: size)
        shade.position = CGPoint(x: size.width / 2, y: size.height / 2)
        modal.addChild(shade)
        let top = size.height - safeTop - 27
        let bottom = safeBottom + 28
        let card = NotebookVisuals.sprite("menu_panel", folder: "ui", height: top - bottom)
        card.size = CGSize(width: size.width - 28, height: top - bottom)
        card.position = CGPoint(x: size.width / 2, y: (top + bottom) / 2)
        modal.addChild(card)
        let heading = NotebookVisuals.label(title, size: 28)
        if heading.frame.width > size.width - 70 {
            heading.fontSize *= (size.width - 70) / heading.frame.width
        }
        heading.position = CGPoint(x: size.width / 2, y: top - 58)
        modal.addChild(heading)
        let sub = NotebookVisuals.label(subtitle, size: 10, color: NotebookVisuals.muted)
        sub.position = CGPoint(x: size.width / 2, y: top - 84)
        modal.addChild(sub)
        let rule = NotebookVisuals.rule(width: size.width - 76)
        rule.position = CGPoint(x: size.width / 2, y: top - 101)
        modal.addChild(rule)
        return (top, bottom)
    }

    private func renderModal() {
        switch modalKind {
        case "intro": showIntro()
        case "craft": renderCraft()
        case "bag": renderBag()
        case "journal": renderJournal()
        case "dialogue": renderDialogue()
        default: break
        }
    }

    private func renderBag() {
        let bounds = modalBase(title: "La mochila de Nib", subtitle: engine.page.name)
        let supplies = NotebookVisuals.label(
            "\(engine.save.scraps) retales   /   \(engine.save.wood) lena   /   \(engine.save.food) bayas", size: 15)
        supplies.position = CGPoint(x: size.width / 2, y: bounds.top - 115)
        modal.addChild(supplies)
        let condition = NotebookVisuals.label(
            "Trazo \(Int(engine.save.integrity))   Comida \(Int(engine.save.hunger))   Calor \(Int(engine.save.warmth))",
            size: 12, color: NotebookVisuals.muted)
        condition.position = CGPoint(x: size.width / 2, y: bounds.top - 143)
        modal.addChild(condition)
        let objective = NotebookVisuals.text(engine.objective, width: size.width - 90, size: 15)
        objective.position = CGPoint(x: size.width / 2, y: bounds.top - 189)
        modal.addChild(objective)
        drawPageMap(center: CGPoint(x: size.width / 2, y: bounds.top - 293))
        let width = (size.width - 90) / 2
        addButton("COMER", id: "eat", x: size.width * 0.30, y: bounds.bottom + 173,
                  width: width, height: 61, modal: true)
        addButton("DESCANSAR", id: "rest", x: size.width * 0.70, y: bounds.bottom + 173,
                  width: width, height: 61, modal: true, font: 12)
        addButton("CONSTRUIR", id: "craft", x: size.width * 0.30, y: bounds.bottom + 111,
                  width: width, height: 61, modal: true, font: 12)
        addButton("DIARIO", id: "journal", x: size.width * 0.70, y: bounds.bottom + 111,
                  width: width, height: 61, modal: true)
        addButton("VOLVER AL MARGEN", id: "close", x: size.width / 2, y: bounds.bottom + 43,
                  width: size.width - 100, height: 56, filled: true, modal: true)
    }

    private func drawPageMap(center: CGPoint) {
        let map = SKNode()
        map.position = center
        modal.addChild(map)
        let scale: CGFloat = size.height < 740 ? 3.7 : 5
        let offset = CGPoint(x: -CGFloat(engine.page.width) * scale / 2,
                             y: -CGFloat(engine.page.height) * scale / 2)
        func position(_ point: PagePoint) -> CGPoint {
            CGPoint(x: offset.x + CGFloat(point.x) * scale, y: offset.y + CGFloat(point.y) * scale)
        }
        for point in engine.page.blocked.union(engine.inkTiles) {
            let dot = SKSpriteNode(color: NotebookVisuals.ink.withAlphaComponent(0.5),
                                   size: CGSize(width: scale, height: scale))
            dot.position = position(point)
            map.addChild(dot)
        }
        for object in engine.page.objects where engine.isAvailable(object) {
            let dot = SKShapeNode(circleOfRadius: 2)
            dot.fillColor = object.pigment.map(NotebookVisuals.color) ?? NotebookVisuals.ink
            dot.strokeColor = .clear
            dot.position = position(object.point)
            map.addChild(dot)
        }
        let hero = NotebookVisuals.label("x", size: 16, color: NotebookVisuals.color(.red))
        hero.position = CGPoint(x: offset.x + CGFloat(engine.save.x) * scale,
                                y: offset.y + CGFloat(engine.save.y) * scale)
        map.addChild(hero)
        let caption = NotebookVisuals.label("Pagina \(engine.page.number) / profundidad \(engine.page.depth)",
                                             size: 10, color: NotebookVisuals.muted)
        caption.position.y = -CGFloat(engine.page.height) * scale / 2 - 15
        map.addChild(caption)
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
            let tile = NotebookVisuals.sprite("button", folder: "ui", height: 72)
            tile.size = CGSize(width: size.width * 0.36, height: 72)
            tile.position = point
            modal.addChild(tile)
            let title = NotebookVisuals.text(visited ? page.name : "Pagina sin abrir",
                                             width: size.width * 0.28, size: 11)
            title.position.y = 9
            tile.addChild(title)
            let number = NotebookVisuals.label(page.id == engine.page.id ? "estas aqui" : "0\(page.number)",
                                               size: 9, color: NotebookVisuals.ink)
            number.position = CGPoint(x: 0, y: -29)
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
                joystick.position = point
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
            joystick.position = point
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
        case 11: perform("bag")
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
