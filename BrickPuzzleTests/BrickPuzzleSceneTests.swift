import SpriteKit
import Testing
@testable import BrickPuzzle

struct BrickPuzzleSceneTests {
    @Test func playbackResolverPrecomputesFinalSequenceBallTracks() throws {
        let level = try LevelBundleLoader().loadLevel(id: "prototype-010")
        var state = try GameState(
            level: level,
            loadout: PowerupLoadout(selectedPowerups: [.extraBalls])
        )
        try state.activatePowerup(.extraBalls)
        try state.beginAiming()
        try state.updateAim(angleDegrees: 90)
        let plan = try ShotPlaybackResolver(state: state).resolve()

        #expect(plan.resolution.frames.map { $0.balls.count }.max() ?? 0 >= 13)
        #expect(plan.ballTracks.count >= 13)
        #expect(plan.ballTracks.allSatisfy { !$0.path.samples.isEmpty })
        #expect(plan.state.snapshot.shotCount == 1)
    }

    @Test func playbackPathInterpolatesWithoutCreatingPerFrameActions() throws {
        let path = BallPlaybackPath(samples: [
            BallPlaybackSample(elapsedTime: 0.5, position: BoardPoint(x: 1, y: 2)),
            BallPlaybackSample(elapsedTime: 1.5, position: BoardPoint(x: 5, y: 6))
        ])

        #expect(path.position(at: 0.49) == nil)
        #expect(path.position(at: 0.5) == BoardPoint(x: 1, y: 2))
        #expect(path.position(at: 1.0) == BoardPoint(x: 3, y: 4))
        #expect(path.position(at: 2.0) == BoardPoint(x: 5, y: 6))
    }

    @MainActor
    @Test func playbackUpdatesExistingBrickNodesInsteadOfRebuildingThem() throws {
        let level = LevelDefinition.prototype
        let scene = BrickPuzzleScene(size: CGSize(width: 390, height: 640))
        scene.configure(level: level)

        let definition = try #require(level.bricks.first)
        let originalNode = try #require(scene.renderedBrickNodeForTesting(id: definition.id))
        let originalPosition = originalNode.position
        let updatedBrick = BrickState(
            id: definition.id,
            coordinate: BoardCoordinate(row: definition.row + 1, column: definition.column),
            kind: definition.kind,
            hitPoints: max(1, definition.hitPoints - 1),
            isDestroyed: false,
            protectionSourceIDs: [],
            lockSourceIDs: []
        )

        scene.renderPlaybackBricksForTesting([updatedBrick])

        let updatedNode = try #require(scene.renderedBrickNodeForTesting(id: definition.id))
        #expect(originalNode === updatedNode)
        #expect(updatedNode.position != originalPosition)
        let label = try #require(updatedNode.childNode(withName: "brick-label") as? SKLabelNode)
        #expect(label.text?.hasSuffix(" \(updatedBrick.hitPoints)") == true)

        var destroyedBrick = updatedBrick
        destroyedBrick.isDestroyed = true
        scene.renderPlaybackBricksForTesting([destroyedBrick])
        #expect(scene.renderedBrickNodeForTesting(id: definition.id) == nil)
    }
}
