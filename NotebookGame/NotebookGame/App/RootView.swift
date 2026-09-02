import SwiftUI
import SpriteKit

/// Hosts the SpriteKit game and keeps the save file honest when the app is
/// backgrounded.
struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase

    /// Built once and kept. Recreating it on every layout pass would restart the
    /// game whenever the view is measured again.
    @State private var scene: SKScene?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(Paper.background)
                if let scene {
                    SpriteView(scene: scene, options: [.ignoresSiblingOrder])
                }
            }
            .ignoresSafeArea()
            .onAppear {
                guard scene == nil else { return }
                scene = makeScene(size: geometry.size)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // Leaving the app is the most likely moment to lose progress, so
            // flush the save whenever we stop being active.
            if phase != .active {
                GameState.shared.persist()
            }
        }
    }

    private func makeScene(size: CGSize) -> SKScene {
        // GeometryReader can report a degenerate size on the first layout pass;
        // fall back to the screen so the scene is never zero-sized.
        let resolved = (size.width > 1 && size.height > 1)
            ? size
            : UIScreen.main.bounds.size

        let scene = TitleScene(size: resolved)
        scene.scaleMode = .resizeFill
        return scene
    }
}
