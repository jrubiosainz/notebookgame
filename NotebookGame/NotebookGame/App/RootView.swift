import SwiftUI
import SpriteKit

/// Hosts SpriteKit. The active adventure scene owns lifecycle persistence, since
/// SpriteKit transitions replace the presented scene without changing this state.
struct RootView: View {

    /// Built once and kept. Recreating it on every layout pass would restart the
    /// game whenever the view is measured again.
    @State private var scene: SKScene?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(Paper.background)
                if let scene {
                    SpriteView(scene: scene)
                }
            }
            .ignoresSafeArea()
            .onAppear {
                guard scene == nil else { return }
                scene = makeScene(size: geometry.size)
            }
        }
    }

    private func makeScene(size: CGSize) -> SKScene {
        // GeometryReader can report a degenerate size on the first layout pass;
        // fall back to the screen so the scene is never zero-sized.
        let resolved = (size.width > 1 && size.height > 1)
            ? size
            : UIScreen.main.bounds.size

        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-notebook-capture"),
           index + 1 < arguments.count, arguments[index + 1] != "cover" {
            let name = arguments[index + 1]
            let scene = AdventureScene(size: resolved,
                                       engine: AdventureEngine(save: AdventurePreviewFixtures.save(for: name)))
            scene.savesEnabled = false
            scene.capturePanel = name == "atlas" ? "journal"
                : name == "workbench" ? "craft" : name == "bag" ? "bag" : nil
            return scene
        }
        #endif
        let scene = AdventureCoverScene(size: resolved)
        scene.scaleMode = .resizeFill
        return scene
    }
}
