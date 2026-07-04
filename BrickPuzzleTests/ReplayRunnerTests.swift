import Foundation
import Testing
@testable import BrickPuzzle

@Suite("Replay validation")
struct ReplayRunnerTests {
    @Test("Bundled prototype replay validates")
    func bundledPrototypeReplayValidates() throws {
        let replay = try ReplayBundleLoader().loadReplay(named: "prototype-001-clean")
        let result = ReplayRunner().validate(replay)

        #expect(result.passed)
        #expect(result.actualOutcome == ReplayActualOutcome(completed: true, stars: 3))
        #expect(result.failureMessage == nil)
    }

    @Test("Failing replay includes level shot expected and actual outcome")
    func failingReplayIncludesUsefulDiagnostics() throws {
        let replay = ReplayFixture(
            levelID: "prototype-001",
            selectedPowerups: [],
            shots: [
                ReplayShot(
                    aimAngleDegrees: 65,
                    usedPowerups: [],
                    destroyedBrickIDs: []
                )
            ],
            expectedOutcome: ReplayExpectedOutcome(completed: true, stars: 3)
        )
        let result = ReplayRunner().validate(replay)
        let message = try #require(result.failureMessage)

        #expect(!result.passed)
        #expect(message.contains("prototype-001"))
        #expect(message.contains("shot 0"))
        #expect(message.contains("Expected completed=true, stars=3"))
        #expect(message.contains("actual completed=false, stars=0"))
    }

    @Test("Replay rejects unselected powerup usage")
    func replayRejectsUnselectedPowerupUsage() throws {
        let replay = ReplayFixture(
            levelID: "prototype-001",
            selectedPowerups: [],
            shots: [
                ReplayShot(
                    aimAngleDegrees: 65,
                    usedPowerups: [.extraBalls],
                    destroyedBrickIDs: ["0-3-mission"]
                )
            ],
            expectedOutcome: ReplayExpectedOutcome(completed: true, stars: 2)
        )
        let result = ReplayRunner().validate(replay)
        let message = try #require(result.failureMessage)

        #expect(!result.passed)
        #expect(message.contains("extraBalls"))
        #expect(message.contains("selected loadout"))
    }

    @Test("Replay rejects unknown destroyed brick id")
    func replayRejectsUnknownDestroyedBrickID() throws {
        let replay = ReplayFixture(
            levelID: "prototype-001",
            selectedPowerups: [],
            shots: [
                ReplayShot(
                    aimAngleDegrees: 65,
                    usedPowerups: [],
                    destroyedBrickIDs: ["missing-brick"]
                )
            ],
            expectedOutcome: ReplayExpectedOutcome(completed: true, stars: 3)
        )
        let result = ReplayRunner().validate(replay)
        let message = try #require(result.failureMessage)

        #expect(!result.passed)
        #expect(message.contains("missing-brick"))
        #expect(message.contains("unknown brick id"))
    }

    @Test("Replay allows three stars with powerups when level rule permits")
    func replayAllowsThreeStarsWithPowerupsWhenLevelRulePermits() throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: directory)
        }

        let level = LevelDefinition(
            id: "powerup-three-star",
            title: "Powerup Three Star",
            columns: 1,
            rows: 1,
            bricks: [
                BrickDefinition(row: 0, column: 0, kind: .mission, hitPoints: 1)
            ],
            availablePowerups: [.extraBalls],
            maxPowerupLoadoutSize: 1,
            starRules: StarRules(
                twoStarShotLimit: 2,
                threeStarRequiresNoPowerups: false,
                threeStarShotLimit: 1
            )
        )
        let levelData = try JSONEncoder().encode(level)
        try levelData.write(to: directory.appendingPathComponent("powerup-three-star.json"))

        let replay = ReplayFixture(
            levelID: "powerup-three-star",
            selectedPowerups: [.extraBalls],
            shots: [
                ReplayShot(
                    aimAngleDegrees: 90,
                    usedPowerups: [.extraBalls],
                    destroyedBrickIDs: ["0-0-mission"]
                )
            ],
            expectedOutcome: ReplayExpectedOutcome(completed: true, stars: 3)
        )
        let runner = ReplayRunner(levelLoader: LevelBundleLoader(levelsDirectoryURL: directory))
        let result = runner.validate(replay)

        #expect(result.passed)
        #expect(result.actualOutcome == ReplayActualOutcome(completed: true, stars: 3))
    }
}
