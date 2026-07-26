import SpriteKit
import SwiftUI

struct SpriteKitGameView: View {
    let level: LevelDefinition
    let loadout: PowerupLoadout
    let reduceMotion: Bool
    let performanceOverlayEnabled: Bool
    let onSnapshot: (GameSnapshot) -> Void
    let onResult: (AttemptResult) -> Void

    @State private var scene = BrickPuzzleScene(size: CGSize(width: 390, height: 640))
    @State private var usedPowerups: Set<PowerupDefinition> = []
    @State private var armedPowerups: Set<PowerupDefinition> = []
    @State private var targetingPowerup: PowerupDefinition?
    @State private var performanceSnapshot = FrameRateSnapshot.empty

    init(
        level: LevelDefinition,
        loadout: PowerupLoadout = .empty,
        reduceMotion: Bool = false,
        performanceOverlayEnabled: Bool = false,
        onSnapshot: @escaping (GameSnapshot) -> Void = { _ in },
        onResult: @escaping (AttemptResult) -> Void = { _ in }
    ) {
        self.level = level
        self.loadout = loadout
        self.reduceMotion = reduceMotion
        self.performanceOverlayEnabled = performanceOverlayEnabled
        self.onSnapshot = onSnapshot
        self.onResult = onResult
    }

    var body: some View {
        VStack(spacing: 8) {
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
                                        .accessibilityIdentifier("powerup-status-\(powerup.rawValue)")
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
                .background(alignment: .topLeading) {
                    Color.clear
                        .frame(width: 1, height: 1)
                        .accessibilityElement(children: .ignore)
                        .accessibilityIdentifier("powerup-controls")
                        .accessibilityLabel("Powerup controls")
                        .allowsHitTesting(false)
                }
            }

            SpriteView(scene: scene, options: [.allowsTransparency])
                .background(Color(.secondarySystemBackground))
                .accessibilityIdentifier("game-board")
                .overlay(alignment: .topTrailing) {
                    if performanceOverlayEnabled {
                        PerformanceOverlay(snapshot: performanceSnapshot)
                            .padding(10)
                    }
                }
        }
        .onAppear {
            scene.configure(level: level, loadout: loadout, reduceMotion: reduceMotion) { snapshot, result in
                onSnapshot(snapshot)
                usedPowerups = Set(snapshot.usedPowerups)
                armedPowerups = Set(snapshot.armedPowerups)
                if targetingPowerup.map(snapshot.usedPowerups.contains) == true {
                    targetingPowerup = nil
                }
                if let result {
                    onResult(result)
                }
            } onPerformanceSnapshot: { snapshot in
                performanceSnapshot = snapshot
            }
        }
    }

    private func statusText(for powerup: PowerupDefinition) -> String {
        if armedPowerups.contains(powerup) {
            switch powerup {
            case .extraBalls:
                return "Armed: +3 balls next shot"
            case .precisionGuide:
                return "Armed: drag to preview bounce"
            default:
                return "Armed"
            }
        }
        if usedPowerups.contains(powerup) { return "Used" }
        if targetingPowerup == powerup { return "Tap field" }
        return "Ready"
    }
}

private struct PerformanceOverlay: View {
    let snapshot: FrameRateSnapshot

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("FPS \(snapshot.currentFramesPerSecond, format: .number.precision(.fractionLength(0))) · min \(snapshot.minimumFramesPerSecond, format: .number.precision(.fractionLength(0)))")
                .accessibilityIdentifier("performance-overlay")
            Text("worst \(snapshot.longestFrameDuration * 1_000, format: .number.precision(.fractionLength(0))) ms · \(snapshot.hitchCount) hitches")
            Text(snapshot.meetsPrototypeThreshold ? "Within prototype threshold" : "Collecting sample")
                .foregroundStyle(snapshot.meetsPrototypeThreshold ? .green : .yellow)
        }
        .font(.caption2.monospacedDigit())
        .padding(7)
        .foregroundStyle(.white)
        .background(.black.opacity(0.74), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Performance: \(Int(snapshot.currentFramesPerSecond.rounded())) frames per second, minimum \(Int(snapshot.minimumFramesPerSecond.rounded())) frames per second, \(Int((snapshot.longestFrameDuration * 1_000).rounded())) millisecond worst frame, \(snapshot.hitchCount) hitches"
        )
    }
}
