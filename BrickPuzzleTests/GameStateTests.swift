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

    @Test("Board geometry validates coordinates and maps authored rows")
    func boardGeometryMapsAuthoredRows() throws {
        let size = BoardSize(columns: 3, rows: 4)
        let geometry = BoardGeometry(size: size)
        let topLeft = try #require(geometry.brickBounds(at: BoardCoordinate(row: 0, column: 0)))
        let bottomRight = try #require(geometry.brickBounds(at: BoardCoordinate(row: 3, column: 2)))

        #expect(topLeft == BoardRect(minX: 0, minY: 3, maxX: 1, maxY: 4))
        #expect(bottomRight == BoardRect(minX: 2, minY: 0, maxX: 3, maxY: 1))
        #expect(geometry.brickBounds(at: BoardCoordinate(row: 4, column: 0)) == nil)
        #expect(geometry.launcherPosition == BoardPoint(x: 1.5, y: -0.65))
    }

    @Test("Aim can be cancelled without consuming a shot")
    func aimCancellationDoesNotConsumeShot() throws {
        var state = GameState(level: simpleLevel(hitPoints: 1))

        try state.beginAiming()
        try state.updateAim(angleDegrees: 90)
        try state.cancelAim()

        #expect(state.snapshot.turnPhase == .idle)
        #expect(state.snapshot.shotCount == 0)
        #expect(state.snapshot.aimAngleDegrees == nil)
    }

    @Test("Shot lifecycle rejects invalid input")
    func shotLifecycleRejectsInvalidInput() throws {
        var state = GameState(level: simpleLevel(hitPoints: 1))

        #expect(throws: GameInputError.invalidPhase) {
            try state.fire()
        }

        try state.beginAiming()
        #expect(throws: GameInputError.invalidAim) {
            try state.updateAim(angleDegrees: 5)
        }
        #expect(state.snapshot.shotCount == 0)
    }

    @Test("A direct shot damages a brick and completes the objective")
    func directShotCompletesObjective() throws {
        var state = GameState(level: simpleLevel(hitPoints: 1))

        try state.beginAiming()
        try state.updateAim(angleDegrees: 90)
        let resolution = try state.fire()

        #expect(!resolution.frames.isEmpty)
        #expect(state.snapshot.shotCount == 1)
        #expect(state.snapshot.missionBrickCount == 0)
        #expect(state.snapshot.turnPhase == .won)
        #expect(state.snapshot.terminalReason == .objectiveCompleted)
        #expect(state.snapshot.balls.isEmpty)
        #expect(state.snapshot.shotHistory.count == 1)
        #expect(state.snapshot.shotHistory[0].destroyedBrickIDs == ["0-1-mission"])
    }

    @Test("Resolved shots return to idle and preserve damage for another turn")
    func multipleTurnsPreserveDamage() throws {
        var state = GameState(level: simpleLevel(hitPoints: 2))

        try fireStraightShot(in: &state)
        #expect(state.snapshot.turnPhase == .idle)
        #expect(state.snapshot.shotCount == 1)
        #expect(state.snapshot.activeBricks.first?.hitPoints == 1)

        try fireStraightShot(in: &state)
        #expect(state.snapshot.turnPhase == .won)
        #expect(state.snapshot.shotCount == 2)
        #expect(state.snapshot.shotHistory.count == 2)
        #expect(state.snapshot.activeBricks.isEmpty)
    }

    @Test("Wall bounces stay inside the playable board")
    func wallBounceStaysInsideBoard() throws {
        var state = GameState(level: simpleLevel(hitPoints: 5))

        try state.beginAiming()
        try state.updateAim(angleDegrees: 25)
        let resolution = try state.fire()
        let inBoardFrames = resolution.frames.filter { $0.position.y >= 0 }

        #expect(inBoardFrames.allSatisfy { (0.11...2.89).contains($0.position.x) })
        #expect(state.snapshot.terminalReason != .simulationLimitReached)
        #expect(state.snapshot.balls.isEmpty)
    }

    @Test("Shot limit produces a terminal failure and blocks further aiming")
    func shotLimitFailsAttempt() throws {
        var state = GameState(level: simpleLevel(hitPoints: 2, shotLimit: 1))

        try fireStraightShot(in: &state)

        #expect(state.snapshot.turnPhase == .failed)
        #expect(state.snapshot.terminalReason == .shotLimitReached)
        #expect(throws: GameInputError.invalidPhase) {
            try state.beginAiming()
        }
    }

    @Test("Danger line produces a terminal failure")
    func dangerLineFailsAttempt() throws {
        let level = LevelDefinition(
            id: "danger-line",
            title: "Danger Line",
            columns: 3,
            rows: 4,
            bricks: [
                BrickDefinition(row: 0, column: 0, kind: .mission, hitPoints: 1),
                BrickDefinition(row: 3, column: 2, kind: .standard, hitPoints: 1)
            ],
            availablePowerups: [],
            maxPowerupLoadoutSize: 0,
            starRules: StarRules(
                twoStarShotLimit: 2,
                threeStarRequiresNoPowerups: true,
                threeStarShotLimit: 1
            ),
            dangerLineRow: 3
        )
        var state = GameState(level: level)

        try fireStraightShot(in: &state)

        #expect(state.snapshot.turnPhase == .failed)
        #expect(state.snapshot.terminalReason == .dangerLineCrossed)
    }

    private func simpleLevel(hitPoints: Int, shotLimit: Int? = nil) -> LevelDefinition {
        LevelDefinition(
            id: "simple",
            title: "Simple",
            columns: 3,
            rows: 4,
            bricks: [
                BrickDefinition(row: 0, column: 1, kind: .mission, hitPoints: hitPoints)
            ],
            availablePowerups: [],
            maxPowerupLoadoutSize: 0,
            starRules: StarRules(
                twoStarShotLimit: 3,
                threeStarRequiresNoPowerups: true,
                threeStarShotLimit: 2
            ),
            shotLimit: shotLimit
        )
    }

    private func fireStraightShot(in state: inout GameState) throws {
        try state.beginAiming()
        try state.updateAim(angleDegrees: 90)
        _ = try state.fire()
    }
}

@Suite("Prototype brick mechanics")
struct BrickMechanicsTests {
    @Test("Standard bricks take damage without being required for mission victory")
    func standardBricksAreOptional() {
        let level = level(bricks: [
            brick("mission", row: 0, column: 0, kind: .mission),
            brick("standard", row: 1, column: 1, kind: .standard, hitPoints: 2)
        ])
        var state = GameState(level: level)

        _ = state.applyDamage(to: "standard")
        #expect(state.snapshot.bricks.first(where: { $0.id == "standard" })?.hitPoints == 1)
        #expect(state.snapshot.turnPhase == .idle)

        _ = state.applyDamage(to: "mission")
        #expect(state.snapshot.turnPhase == .won)
        #expect(state.snapshot.activeBricks.contains(where: { $0.id == "standard" }))
    }

    @Test("A level with no mission bricks begins completed")
    func zeroMissionBricksBeginCompleted() {
        let state = GameState(level: level(bricks: [
            brick("standard", row: 0, column: 0, kind: .standard)
        ]))

        #expect(state.snapshot.turnPhase == .won)
        #expect(state.snapshot.terminalReason == .objectiveCompleted)
    }

    @Test("Shield links block damage until every protecting shield is removed")
    func shieldsProtectLinkedTarget() {
        let level = level(
            bricks: [
                brick("shield-a", row: 0, column: 0, kind: .shield),
                brick("shield-b", row: 0, column: 2, kind: .shield),
                brick("mission", row: 0, column: 1, kind: .mission)
            ],
            shieldLinks: [
                ShieldLink(shieldID: "shield-a", protectedBrickIDs: ["mission"]),
                ShieldLink(shieldID: "shield-b", protectedBrickIDs: ["mission"])
            ]
        )
        var state = GameState(level: level)

        let blocked = state.applyDamage(to: "mission")
        #expect(blocked.contains(where: { $0.kind == .damageBlocked }))
        #expect(state.snapshot.bricks.first(where: { $0.id == "mission" })?.hitPoints == 1)

        _ = state.applyDamage(to: "shield-a")
        #expect(state.snapshot.bricks.first(where: { $0.id == "mission" })?.isProtected == true)
        _ = state.applyDamage(to: "shield-b")
        #expect(state.snapshot.bricks.first(where: { $0.id == "mission" })?.isProtected == false)

        _ = state.applyDamage(to: "mission")
        #expect(state.snapshot.turnPhase == .won)
    }

    @Test("Key destruction unlocks targets and wrong-order damage is blocked")
    func keysUnlockTargets() {
        let level = level(
            bricks: [
                brick("key", row: 1, column: 0, kind: .key),
                brick("locked", row: 1, column: 1, kind: .standard),
                brick("mission", row: 0, column: 0, kind: .mission)
            ],
            keyLinks: [KeyLink(keyID: "key", lockedBrickIDs: ["locked"])]
        )
        var state = GameState(level: level)

        let blocked = state.applyDamage(to: "locked")
        #expect(blocked.contains(where: { $0.kind == .damageBlocked }))
        #expect(state.snapshot.bricks.first(where: { $0.id == "locked" })?.isLocked == true)

        let keyEvents = state.applyDamage(to: "key")
        #expect(keyEvents.contains(where: { $0.kind == .targetUnlocked }))
        #expect(state.snapshot.bricks.first(where: { $0.id == "locked" })?.isLocked == false)

        _ = state.applyDamage(to: "locked")
        #expect(state.snapshot.bricks.first(where: { $0.id == "locked" })?.isDestroyed == true)
    }

    @Test("Bomb chains resolve once in deterministic order")
    func bombsChainDeterministically() {
        let level = level(columns: 5, rows: 5, bricks: [
            brick("mission", row: 0, column: 0, kind: .mission),
            brick("bomb-a", row: 2, column: 2, kind: .bomb),
            brick("bomb-b", row: 2, column: 3, kind: .bomb),
            brick("target", row: 2, column: 4, kind: .standard)
        ])
        var first = GameState(level: level)
        var second = GameState(level: level)

        let firstEvents = first.applyDamage(to: "bomb-a")
        let secondEvents = second.applyDamage(to: "bomb-a")

        #expect(firstEvents == secondEvents)
        #expect(firstEvents.filter { $0.kind == .bombTriggered }.map(\.subjectID) == ["bomb-a", "bomb-b"])
        #expect(first.snapshot.bricks.first(where: { $0.id == "target" })?.isDestroyed == true)
        #expect(first.snapshot.bricks.first(where: { $0.id == "mission" })?.isDestroyed == false)
    }

    @Test("Ordered objectives record correct and out-of-order completion")
    func objectiveSequenceTracksOrder() {
        let orderedLevel = level(
            bricks: [
                brick("mission-a", row: 0, column: 0, kind: .mission),
                brick("mission-b", row: 0, column: 1, kind: .mission)
            ],
            objective: ObjectiveDefinition(
                kind: .clearMissionBricks,
                orderedBrickIDs: ["mission-a", "mission-b"]
            )
        )
        var correct = GameState(level: orderedLevel)
        _ = correct.applyDamage(to: "mission-a")
        _ = correct.applyDamage(to: "mission-b")

        #expect(correct.snapshot.objectiveProgress.completedBrickIDs == ["mission-a", "mission-b"])
        #expect(!correct.snapshot.objectiveProgress.wasCompletedOutOfOrder)
        #expect(correct.snapshot.turnPhase == .won)

        var incorrect = GameState(level: orderedLevel)
        let events = incorrect.applyDamage(to: "mission-b")
        #expect(events.contains(where: { $0.kind == .objectiveOrderViolated }))
        #expect(incorrect.snapshot.objectiveProgress.wasCompletedOutOfOrder)
        #expect(incorrect.snapshot.objectiveProgress.nextRequiredBrickID == "mission-a")
    }

    @Test("Splitter spawns capped deterministic ball paths")
    func splitterSpawnsDeterministicBalls() throws {
        let splitterLevel = level(columns: 3, rows: 4, bricks: [
            brick("mission", row: 0, column: 0, kind: .mission, hitPoints: 5),
            brick("splitter", row: 2, column: 1, kind: .splitter, hitPoints: 2)
        ])
        var first = GameState(level: splitterLevel)
        var second = GameState(level: splitterLevel)

        let firstResolution = try fireStraightShot(in: &first)
        let secondResolution = try fireStraightShot(in: &second)

        #expect(firstResolution == secondResolution)
        #expect(firstResolution.frames.map { $0.balls.count }.max() == 3)
        #expect(first.snapshot.shotHistory[0].events.contains(where: { $0.kind == .ballsSplit }))

        let cappedSimulation = GameSimulationConfiguration(
            ballRadius: 0.12,
            ballSpeed: 7,
            fixedTimeStep: 1.0 / 120.0,
            maximumSteps: 2_400,
            animationSampleStride: 2,
            maximumActiveBalls: 2,
            splitterAngleOffsetDegrees: 18
        )
        var capped = GameState(level: splitterLevel, simulation: cappedSimulation)
        let cappedResolution = try fireStraightShot(in: &capped)
        #expect(cappedResolution.frames.map { $0.balls.count }.max() == 2)
    }

    private func level(
        id: String = "mechanics",
        columns: Int = 3,
        rows: Int = 3,
        bricks: [BrickDefinition],
        objective: ObjectiveDefinition = .clearMissionBricks,
        shieldLinks: [ShieldLink] = [],
        keyLinks: [KeyLink] = []
    ) -> LevelDefinition {
        LevelDefinition(
            id: id,
            title: "Mechanics",
            columns: columns,
            rows: rows,
            bricks: bricks,
            availablePowerups: [],
            maxPowerupLoadoutSize: 0,
            starRules: StarRules(
                twoStarShotLimit: 5,
                threeStarRequiresNoPowerups: true,
                threeStarShotLimit: 3
            ),
            objective: objective,
            shieldLinks: shieldLinks,
            keyLinks: keyLinks
        )
    }

    private func brick(
        _ id: String,
        row: Int,
        column: Int,
        kind: BrickKind,
        hitPoints: Int = 1
    ) -> BrickDefinition {
        BrickDefinition(id: id, row: row, column: column, kind: kind, hitPoints: hitPoints)
    }

    private func fireStraightShot(in state: inout GameState) throws -> ShotResolution {
        try state.beginAiming()
        try state.updateAim(angleDegrees: 90)
        return try state.fire()
    }
}
