import AppKit
import SpriteKit

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
        skView.ignoresSiblingOrder = true
        skView.preferredFramesPerSecond = 60
        window.contentView = skView
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(skView)
        NSApplication.shared.activate(ignoringOtherApps: true)
        let args = CommandLine.arguments
        if args.contains("--validate") {
            validatePresentation()
        } else if let index = args.firstIndex(of: "--capture"), index + 1 < args.count {
            destination = URL(fileURLWithPath: args[index + 1], isDirectory: true)
            do { try FileManager.default.createDirectory(at: destination!, withIntermediateDirectories: true) }
            catch { fail(error) }
            prepareCaptures()
            nextCapture()
        } else {
            skView.presentScene(AdventureCoverScene(size: sceneSize))
            print("Native preview: WASD/arrows move, E interacts, Space erases, C builds, J opens journal.")
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    private func adventure(_ save: AdventureSave) -> AdventureScene {
        let scene = AdventureScene(size: sceneSize, engine: AdventureEngine(save: save))
        scene.savesEnabled = false
        return scene
    }

    private func validatePresentation() {
        let scene = adventure(.fresh)
        skView.presentScene(scene)
        scene.isPaused = true
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
        scene.engine.save.x = 12
        scene.engine.save.y = 11
        scene.perform("interact")
        precondition(scene.engine.save.painted.contains("first_chest"), "Context action paints")
        precondition(!scene.engine.save.collected.contains("first_chest"), "Painting is not opening")
        scene.perform("interact")
        precondition(scene.engine.save.collected.contains("first_chest"), "Second interaction opens")
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
        scene.perform("cover")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
            precondition(skView.scene is AdventureCoverScene, "Successful save permits exit")
            print("Presentation validation passed: modal pause/input, paint/open, placement, save failure retention.")
            NSApplication.shared.terminate(nil)
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
            })
        ]
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
