import SpriteKit
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

final class AdventureCoverScene: SKScene {
    private var buttons: [NotebookButton] = []
    private var confirming = false
    private var loadError: String?

    override func didMove(to view: SKView) {
        scaleMode = .resizeFill
        build()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        if view != nil { build() }
    }

    private func build() {
        removeAllChildren()
        buttons.removeAll()
        backgroundColor = NotebookVisuals.paper
        let backdrop = NotebookVisuals.sprite("title_backdrop", folder: "title", height: size.height)
        backdrop.size.width = size.height * 1.5
        backdrop.position = CGPoint(x: size.width / 2, y: size.height * 0.51)
        backdrop.alpha = 0.23
        addChild(backdrop)
        for i in 0...Int(size.height / 29) {
            let rule = NotebookVisuals.rule(width: size.width, color: NotebookVisuals.blue.withAlphaComponent(0.10))
            rule.position = CGPoint(x: size.width / 2, y: CGFloat(i) * 29)
            addChild(rule)
        }
        let margin = SKSpriteNode(color: NotebookVisuals.color(.red).withAlphaComponent(0.24),
                                  size: CGSize(width: 1, height: size.height))
        margin.position = CGPoint(x: 33, y: size.height / 2)
        addChild(margin)
        for y in stride(from: 65, to: Int(size.height), by: 91) {
            let hole = SKShapeNode(ellipseOf: CGSize(width: 13, height: 22))
            hole.fillColor = SKColor(white: 0.72, alpha: 1)
            hole.strokeColor = NotebookVisuals.muted.withAlphaComponent(0.3)
            hole.position = CGPoint(x: 11, y: CGFloat(y))
            addChild(hole)
        }
        let eyebrow = NotebookVisuals.label("UNA HISTORIA QUE SE NIEGA A DESAPARECER", size: 9,
                                            color: NotebookVisuals.muted, sans: true)
        eyebrow.position = CGPoint(x: size.width / 2 + 8, y: size.height * 0.88)
        addChild(eyebrow)
        let title = NotebookVisuals.label("NOTEBOOK", size: size.width * 0.111)
        title.position = CGPoint(x: size.width / 2 + 7, y: size.height * 0.81)
        title.zRotation = -0.024
        addChild(title)
        let subtitle = NotebookVisuals.label("E L   D E S B O R D E", size: 16, color: NotebookVisuals.blue)
        subtitle.position = CGPoint(x: size.width / 2 + 8, y: size.height * 0.755)
        addChild(subtitle)
        let wash = NotebookVisuals.wash(radius: 111, color: NotebookVisuals.color(.yellow).withAlphaComponent(0.15))
        wash.position = CGPoint(x: size.width / 2 + 8, y: size.height * 0.54)
        addChild(wash)
        let hero = NotebookVisuals.sprite("nib_idle", folder: "characters", height: min(236, size.height * 0.29))
        hero.position = wash.position
        addChild(hero)
        let eraser = NotebookVisuals.eraser(size: 51)
        eraser.position = CGPoint(x: hero.position.x + 49, y: hero.position.y - 16)
        addChild(eraser)
        hero.run(.repeatForever(.sequence([.moveBy(x: 0, y: 5, duration: 1.7),
                                          .moveBy(x: 0, y: -5, duration: 1.7)])))
        for (i, color) in Pigment.allCases.enumerated() {
            let mote = NotebookVisuals.wash(radius: 7, color: NotebookVisuals.color(color))
            mote.position = CGPoint(x: size.width / 2 - 65 + CGFloat(i) * 28, y: size.height * 0.36)
            addChild(mote)
        }
        let tagline = NotebookVisuals.label("Explora. Pinta. Sobrevive.", size: 16)
        tagline.position = CGPoint(x: size.width / 2 + 8, y: size.height * 0.315)
        addChild(tagline)
        if confirming {
            let warning = NotebookVisuals.text("Comenzar de nuevo sustituye tu aventura actual.",
                                               width: size.width - 95, size: 13)
            warning.position = CGPoint(x: size.width / 2 + 6, y: size.height * 0.255)
            addChild(warning)
            button("EMPEZAR DE NUEVO", id: "confirm", y: size.height * 0.18, filled: true)
            button("CONSERVAR MI AVENTURA", id: "cancel", y: size.height * 0.11)
        } else {
            let hasSave = AdventureStore.hasSave
            button(hasSave ? "CONTINUAR EL CUADERNO" : "ABRIR EL CUADERNO",
                   id: hasSave ? "continue" : "new", y: size.height * 0.235, filled: true)
            if hasSave { button("NUEVA HISTORIA", id: "new", y: size.height * 0.165) }
            let footer = NotebookVisuals.label("SEIS PAGINAS  /  TRES PROFUNDIDADES  /  TU HUELLA", size: 8,
                                               color: NotebookVisuals.muted, sans: true)
            footer.position = CGPoint(x: size.width / 2 + 7, y: size.height * 0.09)
            addChild(footer)
        }
        if let loadError {
            let message = NotebookVisuals.text(loadError, width: size.width - 60, size: 12,
                                                color: NotebookVisuals.color(.red))
            message.position = CGPoint(x: size.width / 2, y: size.height * 0.045)
            addChild(message)
        }
    }

    private func button(_ title: String, id: String, y: CGFloat, filled: Bool = false) {
        let button = NotebookButton(title, id: id, width: min(300, size.width - 88), height: 49,
                                    filled: filled, fontSize: 12)
        button.position = CGPoint(x: size.width / 2 + 7, y: y)
        addChild(button)
        buttons.append(button)
    }

    private func select(_ point: CGPoint) {
        guard let button = buttons.first(where: { $0.hit(point, in: self) }) else { return }
        NotebookVisuals.tapFeedback()
        switch button.actionID {
        case "new":
            if AdventureStore.hasSave { confirming = true; build() }
            else { enter(.fresh) }
        case "confirm": enter(.fresh)
        case "cancel": confirming = false; build()
        case "continue":
            if let save = AdventureStore.load() { enter(save) } else {
                loadError = "No se pudo leer la partida. No se ha sobrescrito."
                build()
            }
        default: break
        }
    }

    private func enter(_ save: AdventureSave) {
        let scene = AdventureScene(size: size, engine: AdventureEngine(save: save))
        view?.presentScene(scene, transition: .fade(with: NotebookVisuals.paper, duration: 0.4))
    }

    #if canImport(UIKit)
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first { select(touch.location(in: self)) }
    }
    #else
    override func mouseUp(with event: NSEvent) { select(event.location(in: self)) }
    #endif
}
