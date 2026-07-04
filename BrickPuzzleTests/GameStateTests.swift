import Testing
@testable import BrickPuzzle

@Suite("Game state")
struct GameStateTests {
    @Test("Prototype level initializes deterministic board state")
    func prototypeLevelInitializesDeterministicBoardState() {
        let level = LevelDefinition.prototype
        let state = GameState(level: level)
        let snapshot = state.snapshot

        #expect(snapshot.levelID == level.id)
        #expect(snapshot.boardSize == BoardSize(columns: 7, rows: 8))
        #expect(snapshot.bricks.count == level.bricks.count)
        #expect(snapshot.missionBrickCount == 1)
        #expect(snapshot.turnPhase == .idle)
        #expect(snapshot.shotCount == 0)
        #expect(snapshot.usedPowerups.isEmpty)
        #expect(snapshot.objective == .clearMissionBricks)
    }
}
