import SpriteKit
import SwiftUI

struct SpriteKitGameView: View {
    let level: LevelDefinition
    let loadout: PowerupLoadout
    let onResult: (AttemptResult) -> Void

    @State private var scene = BrickPuzzleScene(size: CGSize(width: 390, height: 640))
    @State private var usedPowerups: Set<PowerupDefinition> = []
    @State private var armedPowerups: Set<PowerupDefinition> = []
    @State private var targetingPowerup: PowerupDefinition?

    init(
        level: LevelDefinition,
        loadout: PowerupLoadout = .empty,
        onResult: @escaping (AttemptResult) -> Void = { _ in }
    ) {
        self.level = level
        self.loadout = loadout
        self.onResult = onResult
    }

    var body: some View {
        VStack(spacing: 8) {
            SpriteView(scene: scene, options: [.allowsTransparency])
                .background(Color(.secondarySystemBackground))
                .accessibilityIdentifier("game-board")

            if !loadout.selectedPowerups.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(loadout.selectedPowerups) { powerup in
                            Button {
                                if powerup == .bomb || powerup == .rowClear {
                                    targetingPowerup = powerup
                                }
                                scene.activatePowerup(powerup)
                            } label: {
                                VStack(spacing: 2) {
                                    Text(powerup.displayName)
                                        .font(.caption.bold())
                                    Text(statusText(for: powerup))
                                        .font(.caption2)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.bordered)
                            .disabled(usedPowerups.contains(powerup))
                            .accessibilityIdentifier("powerup-\(powerup.rawValue)")
                        }
                    }
                }
                .accessibilityIdentifier("powerup-controls")
            }
        }
        .onAppear {
            scene.configure(level: level, loadout: loadout) { snapshot, result in
                usedPowerups = Set(snapshot.usedPowerups)
                armedPowerups = Set(snapshot.armedPowerups)
                if targetingPowerup.map(snapshot.usedPowerups.contains) == true {
                    targetingPowerup = nil
                }
                if let result {
                    onResult(result)
                }
            }
        }
    }

    private func statusText(for powerup: PowerupDefinition) -> String {
        if usedPowerups.contains(powerup) { return "Used" }
        if armedPowerups.contains(powerup) { return "Armed" }
        if targetingPowerup == powerup { return "Tap field" }
        return "Ready"
    }
}
