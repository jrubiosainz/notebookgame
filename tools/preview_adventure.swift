import AppKit
import SpriteKit
import ImageIO
import UniformTypeIdentifiers

/// Runs the same scene as iPhone without requiring an iOS Simulator runtime.
/// Capture fixtures never read or write the player's save.
@main
struct NotebookPreview {
    static func main() {
        let app = NSApplication.shared
        let delegate = PreviewDelegate()
        app.setActivationPolicy(.regular)
        app.delegate = delegate
        app.run()
        withExtendedLifetime(delegate) {}
    }
}

final class PreviewDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var skView: SKView!
    private let sceneSize = CommandLine.arguments.contains("--compact")
        ? CGSize(width: 375, height: 667) : CGSize(width: 430, height: 932)
    private var captures: [(String, () -> SKScene)] = []
    private var captureIndex = 0
    private var destination: URL?

    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: CGRect(origin: .zero, size: sceneSize),
                          styleMask: [.titled, .closable, .miniaturizable],
                          backing: .buffered, defer: false)
        window.title = "Notebook - El desborde | Native SpriteKit preview"
        window.center()
        skView = SKView(frame: CGRect(origin: .zero, size: sceneSize))
        skView.ignoresSiblingOrder = false
        skView.preferredFramesPerSecond = 60
        window.contentView = skView
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(skView)
        NSApplication.shared.activate(ignoringOtherApps: true)
        let args = CommandLine.arguments
        if args.contains("--validate") {
            validatePresentation()
        } else if let index = args.firstIndex(of: "--animate"), index + 1 < args.count {
            captureAnimation(to: URL(fileURLWithPath: args[index + 1]))
        } else if let index = args.firstIndex(of: "--capture"), index + 1 < args.count {
            destination = URL(fileURLWithPath: args[index + 1], isDirectory: true)
            do { try FileManager.default.createDirectory(at: destination!, withIntermediateDirectories: true) }
            catch { fail(error) }
            prepareCaptures()
            nextCapture()
        } else {
            skView.presentScene(AdventureCoverScene(size: sceneSize))
            print("Native preview: WASD/arrows move, E interacts, Space erases, B opens bag, C builds, J opens journal.")
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    private func adventure(_ save: AdventureSave) -> AdventureScene {
        let scene = AdventureScene(size: sceneSize, engine: AdventureEngine(save: save))
        scene.savesEnabled = false
        return scene
    }

    private func validatePresentation() {
        validateNibAnimations()
        let cover = AdventureCoverScene(size: sceneSize)
        skView.presentScene(cover)
        precondition(cover.childNode(withName: "//eraser-tool") == nil, "Cover shows only Nib, without an eraser")
        let scene = adventure(.fresh)
        skView.presentScene(scene)
        scene.isPaused = true
        precondition(scene.childNode(withName: "//eraser-tool") == nil, "Idle Nib has no floating eraser")
        guard let hud = scene.childNode(withName: "adventure-hud"),
              let stick = hud.childNode(withName: "//original-joystick-base") as? SKSpriteNode else {
            preconditionFailure("The original illustrated joystick must be present")
        }
        precondition(stick.texture === NotebookVisuals.texture("joystick_base", folder: "ui"),
                     "Use the original joystick artwork, not a geometric replacement")
        precondition(!hud.children.contains {
            let frame = $0.calculateAccumulatedFrame()
            return frame.width >= scene.size.width * 0.9 && frame.height > 80
        }, "Gameplay must not reserve broad header or footer panels")
        let opening = scene.engine.save
        scene.update(1)
        scene.update(2)
        precondition(scene.engine.save == opening, "The opening must pause simulation")
        scene.perform("erase")
        precondition(scene.engine.save == opening, "Modal blocks action leakage")
        scene.perform("intro-skip")
        precondition(scene.engine.save.introSeen, "Opening can be dismissed explicitly")
        scene.perform("journal")
        let paused = scene.engine.save
        scene.update(3)
        scene.update(4)
        scene.perform("eat")
        precondition(scene.engine.save == paused, "Journal pauses survival and blocks food shortcuts")
        for _ in 0..<10 { scene.perform("journal-next") }
        scene.perform("close")
        scene.engine.save.x = 8
        scene.engine.save.y = 11
        scene.perform("interact")
        precondition(scene.engine.save.colors.contains(.brown), "Context action discovers pigment")
        guard let nib = scene.childNode(withName: "//nib") as? NibAnimator else {
            preconditionFailure("Adventure must use the directional Nib animator")
        }
        precondition(nib.gesture == nil, "Discovering pigment is not the painting gesture")
        scene.engine.save.x = 12
        scene.engine.save.y = 11
        scene.perform("interact")
        precondition(scene.engine.save.painted.contains("first_chest"), "Context action paints")
        precondition(!scene.engine.save.collected.contains("first_chest"), "Painting is not opening")
        precondition(nib.gesture == .paint(.brown), "Painting an object animates Nib's brush gesture")
        scene.perform("interact")
        precondition(scene.engine.save.collected.contains("first_chest"), "Second interaction opens")
        scene.perform("erase")
        precondition(nib.gesture == .erase, "Eraser action reaches the character animation")
        let beforeBag = scene.engine.save
        scene.perform("bag")
        precondition(scene.engine.save == beforeBag, "Bag opens without changing the world")
        scene.perform("craft")
        scene.perform("build-path")
        scene.engine.save.x = 10
        scene.engine.save.y = 6
        scene.engine.save.facing = PagePoint(x: 1, y: 0)
        scene.perform("interact")
        precondition(scene.engine.save.builds.last?.kind == .path, "Placement control reaches the engine")
        scene.perform("craft")
        scene.perform("cancel-build")
        scene.savesEnabled = true
        scene.saveHandler = { _ in
            throw NSError(domain: "NotebookPreview.ExpectedSaveFailure", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Injected disk failure"])
        }
        scene.perform("journal")
        scene.perform("cover")
        precondition(skView.scene === scene, "Failed save must retain the live adventure")
        scene.saveHandler = { _ in }
        scene.isPaused = false
        scene.perform("cover")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [self] in
            precondition(skView.scene is AdventureCoverScene, "Successful save permits exit")
            print("Presentation validation passed: modal pause/input, paint/open, placement, save failure retention.")
            NSApplication.shared.terminate(nil)
        }
    }

    private func validateNibAnimations() {
        let nib = NibAnimator()
        let body = nib.childNode(withName: "nib-body") as! SKSpriteNode
        for facing in NibAnimator.Facing.allCases {
            nib.reset(facing: facing)
            precondition(!nib.isHoldingTool && nib.frameIndex == 1, "No floating tool in a resting pose")
            var frames: Set<Int> = []
            for _ in 0..<20 {
                nib.update(dt: 1.0 / 60, displacement: CGVector(dx: facing.direction.dx * 0.09,
                                                              dy: facing.direction.dy * 0.09),
                           heading: facing.direction)
                frames.insert(nib.frameIndex)
                let textureSize = body.texture!.size()
                precondition(body.texture === NotebookVisuals.texture("frame_\(nib.frameIndex)", folder: facing.sheet),
                             "Walking uses the actual frames from the intended directional sheet")
                precondition(abs(body.size.width / body.size.height - textureSize.width / textureSize.height) < 0.00001,
                             "Every directional frame preserves its drawn proportions")
                precondition(body.anchorPoint.y == 0, "All poses remain anchored at the feet")
                precondition(body.size.height <= 76.001, "Frames keep a consistent character height")
            }
            precondition(frames.count == 4 && nib.isWalking, "Every direction plays all four actual walking frames")
            precondition((body.xScale < 0) == (facing == .left), "Only the left-facing sheet is mirrored")
            nib.update(dt: 0.1, displacement: .zero, heading: .zero)
            precondition(!nib.isWalking && nib.frameIndex == 1 && nib.facing == facing,
                         "Stopping retains the direction instead of snapping to a different idle drawing")
        }
        let fast = NibAnimator()
        let slow = NibAnimator()
        for _ in 0..<10 {
            fast.update(dt: 0.05, displacement: CGVector(dx: 0.113, dy: 0), heading: CGVector(dx: 1, dy: 0))
            for _ in 0..<2 {
                slow.update(dt: 0.05, displacement: CGVector(dx: 0.0565, dy: 0), heading: CGVector(dx: 1, dy: 0))
            }
        }
        precondition(fast.frameIndex == slow.frameIndex, "Gait follows distance, not joystick speed or frame rate")
        for gesture in [NibAnimator.Gesture.erase, .paint(.brown)] {
            nib.reset(facing: .down)
            nib.play(gesture, toward: CGVector(dx: 1, dy: 0))
            precondition(nib.facing == .right && !nib.isHoldingTool, "Gesture begins with a directional wind-up")
            nib.update(dt: 0.12, displacement: .zero, heading: .zero)
            precondition(nib.isHoldingTool && body.position != .zero, "Active gesture has a body pose and held tool")
            let pose = nib.frameIndex
            nib.update(dt: 0, displacement: .zero, heading: .zero)
            precondition(nib.frameIndex == pose && nib.gesture == gesture, "Paused animation does not advance")
            nib.update(dt: 0.5, displacement: .zero, heading: .zero)
            precondition(nib.gesture == nil && !nib.isHoldingTool
                         && nib.childNode(withName: "nib-held-tool")!.children.isEmpty,
                         "Tools are put away completely after painting or erasing")
        }
        nib.play(.paint(.red), toward: CGVector(dx: 0, dy: 1))
        nib.play(.erase, toward: CGVector(dx: -1, dy: 0))
        precondition(nib.gesture == .erase && nib.childNode(withName: "nib-held-tool")!.children.count == 1,
                     "A new gesture replaces rather than stacks tools")
        nib.reset(facing: .up)
        precondition(nib.gesture == nil && !nib.isHoldingTool, "Page transitions clear transient gestures")
        print("Nib animation validation passed: four directions, gait, proportions, rest, paint, erase, pause and cleanup.")
    }

    private func captureAnimation(to url: URL) {
        let showcase = NibMotionShowcase(size: sceneSize)
        skView.presentScene(showcase)
        guard let output = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, 36, nil) else {
            fail(NSError(domain: "NotebookPreview", code: 3,
                         userInfo: [NSLocalizedDescriptionKey: "Cannot create the animation capture."]))
        }
        CGImageDestinationSetProperties(output, [kCGImagePropertyGIFDictionary:
            [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        var index = 0
        Timer.scheduledTimer(withTimeInterval: 1.0 / 12, repeats: true) { [self] timer in
            guard let texture = skView.texture(from: showcase, crop: CGRect(origin: .zero, size: sceneSize)) else {
                timer.invalidate()
                fail(NSError(domain: "NotebookPreview", code: 4,
                             userInfo: [NSLocalizedDescriptionKey: "Cannot render the animated poses."]))
            }
            CGImageDestinationAddImage(output, texture.cgImage(), [kCGImagePropertyGIFDictionary:
                [kCGImagePropertyGIFDelayTime: 1.0 / 12]] as CFDictionary)
            index += 1
            if index == 36 {
                timer.invalidate()
                precondition(CGImageDestinationFinalize(output), "Animation must encode successfully")
                print("Saved live Nib animation: \(url.path)")
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private func prepareCaptures() {
        captures = [
            ("01-cover", { AdventureCoverScene(size: self.sceneSize) }),
            ("02-prologue", { self.adventure(.fresh) }),
            ("03-first-pigment", {
                self.adventure(AdventurePreviewFixtures.save(for: "first-pigment"))
            }),
            ("04-brown-awakening", {
                self.adventure(AdventurePreviewFixtures.save(for: "brown-awakening"))
            }),
            ("05-a-light-in-the-ink", {
                self.adventure(AdventurePreviewFixtures.save(for: "camp"))
            }),
            ("06-notebook-atlas", {
                let scene = self.adventure(AdventurePreviewFixtures.save(for: "camp"))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { scene.perform("journal") }
                return scene
            }),
            ("07-the-violet-seam", {
                self.adventure(AdventurePreviewFixtures.save(for: "violet-seam"))
            }),
            ("08-the-workbench", {
                let scene = self.adventure(AdventurePreviewFixtures.save(for: "camp"))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { scene.perform("craft") }
                return scene
            }),
            ("09-the-bag", {
                let scene = self.adventure(AdventurePreviewFixtures.save(for: "camp"))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { scene.perform("bag") }
                return scene
            })
        ]
    }

    final class NibMotionShowcase: SKScene {
        private var actors: [NibAnimator] = []
        private var lastTime: TimeInterval = 0
        private var elapsed: Double = 0
        private var nextGesture: Double = 0

        override func didMove(to view: SKView) {
            backgroundColor = NotebookVisuals.paper
            let title = NotebookVisuals.label("Los trazos de Nib", size: 29)
            title.position = CGPoint(x: size.width / 2, y: size.height - 65)
            addChild(title)
            for (index, direction) in NibAnimator.Facing.allCases.enumerated() {
                let actor = NibAnimator(height: 125)
                actor.reset(facing: direction)
                actor.position = CGPoint(x: size.width * (index % 2 == 0 ? 0.28 : 0.72),
                                         y: size.height - 285 - CGFloat(index / 2) * 225)
                addChild(actor)
                actors.append(actor)
                let caption = NotebookVisuals.label(["Hacia abajo", "Hacia arriba", "Izquierda", "Derecha"][index], size: 16)
                caption.position = CGPoint(x: actor.position.x, y: actor.position.y - 32)
                addChild(caption)
            }
            for index in 0..<2 {
                let actor = NibAnimator(height: 125)
                actor.position = CGPoint(x: size.width * (index == 0 ? 0.28 : 0.72), y: 125)
                addChild(actor)
                actors.append(actor)
                let caption = NotebookVisuals.label(index == 0 ? "Borrar" : "Pintar", size: 16)
                caption.position = CGPoint(x: actor.position.x, y: 90)
                addChild(caption)
            }
        }

        override func update(_ currentTime: TimeInterval) {
            let dt = lastTime == 0 ? 0 : min(0.05, currentTime - lastTime)
            lastTime = currentTime
            elapsed += dt
            for (index, actor) in actors.enumerated() {
                let direction = actor.facing.direction
                actor.update(dt: dt, displacement: index < 4
                             ? CGVector(dx: direction.dx * dt * 2.4, dy: direction.dy * dt * 2.4) : .zero,
                             heading: direction)
            }
            if elapsed >= nextGesture, actors.count == 6 {
                nextGesture = elapsed + 0.9
                actors[4].play(.erase, toward: CGVector(dx: 1, dy: 0))
                actors[5].play(.paint(.brown), toward: CGVector(dx: -1, dy: 0))
            }
        }
    }

    private func nextCapture() {
        guard captureIndex < captures.count else {
            print("Captured \(captures.count) real SpriteKit scenes at \(destination!.path).")
            NSApplication.shared.terminate(nil)
            return
        }
        let entry = captures[captureIndex]
        let scene = entry.1()
        skView.presentScene(scene)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [self] in
            scene.isPaused = true
            guard let texture = skView.texture(from: scene, crop: CGRect(origin: .zero, size: sceneSize)) else {
                fail(NSError(domain: "NotebookPreview", code: 1,
                             userInfo: [NSLocalizedDescriptionKey: "SpriteKit could not render the capture."]))
            }
            let bitmap = NSBitmapImageRep(cgImage: texture.cgImage())
            guard let data = bitmap.representation(using: .png, properties: [:]) else {
                fail(NSError(domain: "NotebookPreview", code: 2,
                             userInfo: [NSLocalizedDescriptionKey: "PNG encoding failed."]))
            }
            do { try data.write(to: destination!.appendingPathComponent(entry.0 + ".png")) }
            catch { fail(error) }
            print("  \(entry.0).png")
            captureIndex += 1
            nextCapture()
        }
    }

    private func fail(_ error: Error) -> Never {
        fputs("Preview failed: \(error.localizedDescription)\n", stderr)
        exit(1)
    }
}
