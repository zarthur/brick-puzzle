import Foundation
import Testing
@testable import BrickPuzzle

@Suite("Replay validation")
struct ReplayRunnerTests {
    @Test("Every bundled level has a passing clean replay")
    func bundledReplaysValidate() throws {
        let levels = try LevelBundleLoader().loadAllLevels()
        let replays = try ReplayBundleLoader().loadAllReplays()
        let replayLevelIDs = Set(replays.map(\.levelID))

        #expect(levels.map(\.id) == [
            "prototype-001", "prototype-002", "prototype-003", "prototype-004",
            "prototype-005", "prototype-006", "prototype-007", "prototype-008",
            "prototype-009", "prototype-010"
        ])
        #expect(replayLevelIDs == Set(levels.map(\.id)))

        for replay in replays {
            let result = ReplayRunner().validate(replay)
            #expect(result.passed, Comment(rawValue: result.failureMessage ?? replay.levelID))
            #expect(result.actualOutcome == ReplayActualOutcome(completed: true, stars: 3))
        }
    }

    @Test("Powerup-assisted late-level clears cannot earn three stars")
    func assistedLateLevelClearsAreCapped() throws {
        for levelID in ["prototype-008", "prototype-009", "prototype-010"] {
            let cleanReplay = try ReplayBundleLoader().loadReplay(named: "\(levelID)-clean")
            let firstShot = try #require(cleanReplay.shots.first)
            let assistedReplay = ReplayFixture(
                levelID: levelID,
                selectedPowerups: [.precisionGuide],
                shots: [
                    ReplayShot(
                        aimAngleDegrees: firstShot.aimAngleDegrees,
                        usedPowerups: [.precisionGuide],
                        destroyedBrickIDs: firstShot.destroyedBrickIDs
                    )
                ] + cleanReplay.shots.dropFirst(),
                expectedOutcome: ReplayExpectedOutcome(completed: true, stars: 2)
            )

            let result = ReplayRunner().validate(assistedReplay)
            #expect(result.passed, Comment(rawValue: result.failureMessage ?? levelID))
            #expect(result.actualOutcome.stars == 2)
        }
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
            ),
            metadata: LevelAuthoringMetadata(
                intendedSolution: "Use the selected helper.",
                minimumKnownShotCount: 1,
                requiredMechanics: [.aiming, .missionObjective],
                difficulty: .easy,
                validationStatus: .replayValidated
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
