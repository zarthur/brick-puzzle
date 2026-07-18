import SpriteKit
import SwiftUI

struct SpriteKitGameView: View {
    let level: LevelDefinition
    @State private var scene = BrickPuzzleScene(size: CGSize(width: 390, height: 640))

    var body: some View {
        SpriteView(scene: scene, options: [.allowsTransparency])
            .background(Color(.secondarySystemBackground))
            .onAppear {
                scene.configure(level: level)
            }
            .accessibilityIdentifier("game-board")
    }
}
