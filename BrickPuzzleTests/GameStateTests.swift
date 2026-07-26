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
        #expect(snapshot.boardSize == BoardSize(columns: 5, rows: 6))
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

    @Test("Shot playback exposes hit point changes and destruction at impact time")
    func shotPlaybackUpdatesBricksAtImpact() throws {
        var damagedState = GameState(level: simpleLevel(hitPoints: 2))
        try damagedState.beginAiming()
        try damagedState.updateAim(angleDegrees: 90)
        let damagedResolution = try damagedState.fire()

        let damageFrame = try #require(damagedResolution.frames.first { frame in
            frame.bricks.first?.hitPoints == 1
        })
        let damagedEndTime = try #require(damagedResolution.frames.last?.elapsedTime)
        #expect(damageFrame.elapsedTime < damagedEndTime)
        #expect(damageFrame.bricks.first?.isDestroyed == false)

        var destroyedState = GameState(level: simpleLevel(hitPoints: 1))
        try destroyedState.beginAiming()
        try destroyedState.updateAim(angleDegrees: 90)
        let destroyedResolution = try destroyedState.fire()

        let destructionFrame = try #require(destroyedResolution.frames.first { frame in
            frame.bricks.first?.isDestroyed == true
        })
        let destroyedEndTime = try #require(destroyedResolution.frames.last?.elapsedTime)
        #expect(destructionFrame.elapsedTime < destroyedEndTime)
        #expect(destructionFrame.bricks.first?.hitPoints == 0)
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

    @Test("Shared edge and corner contacts damage every intersecting brick")
    func sharedContactsDamageEveryBrick() throws {
        let contactBricks = [
            brick("contact-left", row: 2, column: 0, kind: .standard, hitPoints: 2),
            brick("contact-right", row: 2, column: 1, kind: .standard, hitPoints: 2)
        ]
        let contactLevel = level(
            columns: 2,
            rows: 4,
            bricks: [brick("mission", row: 0, column: 0, kind: .mission, hitPoints: 50)]
                + contactBricks
        )
        var state = GameState(level: contactLevel)

        let resolution = try fireStraightShot(in: &state)
        let firstContactFrame = try #require(resolution.frames.first { frame in
            frame.bricks.contains { $0.id.hasPrefix("contact-") && $0.hitPoints < 2 }
        })
        let remainingHitPoints = firstContactFrame.bricks
            .filter { $0.id.hasPrefix("contact-") }
            .sorted { $0.id < $1.id }
            .map(\.hitPoints)

        #expect(remainingHitPoints == [1, 1])

        let cornerBricks = [
            brickState("corner-a", row: 2, column: 0),
            brickState("corner-b", row: 2, column: 1),
            brickState("corner-c", row: 1, column: 0)
        ]
        let geometry = BoardGeometry(size: BoardSize(columns: 2, rows: 4))
        let cornerContacts = geometry.collidingBrickIndices(
            at: BoardPoint(x: 1, y: 2),
            radius: 0.2,
            bricks: cornerBricks
        )
        #expect(cornerContacts.map { cornerBricks[$0].id } == ["corner-a", "corner-b", "corner-c"])
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

    private func brickState(_ id: String, row: Int, column: Int) -> BrickState {
        BrickState(
            id: id,
            coordinate: BoardCoordinate(row: row, column: column),
            kind: .standard,
            hitPoints: 1,
            isDestroyed: false,
            protectionSourceIDs: [],
            lockSourceIDs: []
        )
    }

    private func fireStraightShot(in state: inout GameState) throws -> ShotResolution {
        try state.beginAiming()
        try state.updateAim(angleDegrees: 90)
        return try state.fire()
    }
}

@Suite("Powerups and star scoring")
struct PowerupAndScoringTests {
    @Test("Attempts reject invalid loadouts and separate selected from used powerups")
    func validatesAndTracksLoadout() throws {
        let level = powerupLevel()
        #expect(throws: PowerupLoadoutError.unavailable([.gravityShift])) {
            _ = try GameState(
                level: level,
                loadout: PowerupLoadout(selectedPowerups: [.gravityShift])
            )
        }

        var state = try GameState(
            level: level,
            loadout: PowerupLoadout(selectedPowerups: [.extraBalls])
        )
        #expect(state.snapshot.selectedPowerups == [.extraBalls])
        #expect(state.snapshot.usedPowerups.isEmpty)

        try state.activatePowerup(.extraBalls)
        #expect(state.snapshot.usedPowerups == [.extraBalls])
        #expect(state.snapshot.armedPowerups == [.extraBalls])
        #expect(throws: PowerupActivationError.alreadyUsed(.extraBalls)) {
            try state.activatePowerup(.extraBalls)
        }
        #expect(throws: PowerupActivationError.notSelected(.bomb)) {
            try state.activatePowerup(.bomb, target: BoardCoordinate(row: 1, column: 1))
        }
    }

    @Test("Extra Balls deterministically adds balls to the next shot")
    func extraBallsModifiesNextShot() throws {
        var state = try GameState(
            level: powerupLevel(missionHitPoints: 5),
            loadout: PowerupLoadout(selectedPowerups: [.extraBalls])
        )
        try state.activatePowerup(.extraBalls)
        try state.beginAiming()
        try state.updateAim(angleDegrees: 90)
        let resolution = try state.fire()

        #expect(resolution.frames.first?.balls.count == 3)
        #expect(state.snapshot.armedPowerups.isEmpty)
        #expect(state.snapshot.usedPowerups == [.extraBalls])
    }

    @Test("Shield Breaker removes protection without destroying shield bricks")
    func shieldBreakerRemovesProtection() throws {
        let level = powerupLevel(
            bricks: [
                brick("shield", row: 0, column: 0, kind: .shield),
                brick("mission", row: 0, column: 1, kind: .mission)
            ],
            shieldLinks: [ShieldLink(shieldID: "shield", protectedBrickIDs: ["mission"])]
        )
        var state = try GameState(
            level: level,
            loadout: PowerupLoadout(selectedPowerups: [.shieldBreaker])
        )

        let events = try state.activatePowerup(.shieldBreaker)

        #expect(state.snapshot.bricks.first(where: { $0.id == "mission" })?.isProtected == false)
        #expect(state.snapshot.bricks.first(where: { $0.id == "shield" })?.isDestroyed == false)
        #expect(events.contains(where: { $0.kind == .shieldRemoved }))
    }

    @Test("Bomb and Row Clear apply deterministic area damage through protection rules")
    func targetedDamagePowerups() throws {
        let bricks = [
            brick("mission", row: 0, column: 0, kind: .mission, hitPoints: 3),
            brick("row-a", row: 1, column: 0, kind: .standard),
            brick("row-b", row: 1, column: 1, kind: .standard),
            brick("far", row: 3, column: 3, kind: .standard)
        ]
        var bombState = try GameState(
            level: powerupLevel(columns: 4, rows: 4, bricks: bricks),
            loadout: PowerupLoadout(selectedPowerups: [.bomb])
        )
        try bombState.activatePowerup(.bomb, target: BoardCoordinate(row: 1, column: 1))
        #expect(bombState.snapshot.bricks.first(where: { $0.id == "row-a" })?.isDestroyed == true)
        #expect(bombState.snapshot.bricks.first(where: { $0.id == "row-b" })?.isDestroyed == true)
        #expect(bombState.snapshot.bricks.first(where: { $0.id == "far" })?.isDestroyed == false)

        var rowState = try GameState(
            level: powerupLevel(columns: 4, rows: 4, bricks: bricks),
            loadout: PowerupLoadout(selectedPowerups: [.rowClear])
        )
        try rowState.activatePowerup(.rowClear, target: BoardCoordinate(row: 1, column: 3))
        #expect(rowState.snapshot.bricks.first(where: { $0.id == "row-a" })?.isDestroyed == true)
        #expect(rowState.snapshot.bricks.first(where: { $0.id == "row-b" })?.isDestroyed == true)
        #expect(rowState.snapshot.bricks.first(where: { $0.id == "mission" })?.hitPoints == 3)
    }

    @Test("Star scoring covers failed, one, two, and three-star attempts")
    func starScoringOutcomes() throws {
        var failed = GameState(level: scoringLevel(shotLimit: 1))
        failed.applyPlaceholderShot(destroyedBrickIDs: [])
        #expect(failed.result?.stars == StarRating.none)

        var oneStar = GameState(level: scoringLevel())
        oneStar.applyPlaceholderShot(destroyedBrickIDs: [])
        oneStar.applyPlaceholderShot(destroyedBrickIDs: [])
        oneStar.applyPlaceholderShot(destroyedBrickIDs: ["mission"])
        #expect(oneStar.result?.stars == .one)

        var twoStar = try GameState(
            level: scoringLevel(),
            loadout: PowerupLoadout(selectedPowerups: [.extraBalls])
        )
        twoStar.applyPlaceholderShot(destroyedBrickIDs: [])
        twoStar.applyPlaceholderShot(
            destroyedBrickIDs: ["mission"],
            usedPowerups: [.extraBalls]
        )
        #expect(twoStar.result?.stars == .two)
        #expect(twoStar.result?.details.contains(.powerupUsed) == true)

        var selectedButUnused = try GameState(
            level: scoringLevel(),
            loadout: PowerupLoadout(selectedPowerups: [.extraBalls])
        )
        selectedButUnused.applyPlaceholderShot(destroyedBrickIDs: ["mission"])
        #expect(selectedButUnused.result?.stars == .three)
    }

    private func scoringLevel(shotLimit: Int? = nil) -> LevelDefinition {
        LevelDefinition(
            id: "scoring",
            title: "Scoring",
            columns: 3,
            rows: 3,
            bricks: [brick("mission", row: 0, column: 0, kind: .mission)],
            availablePowerups: [.extraBalls],
            maxPowerupLoadoutSize: 1,
            starRules: StarRules(
                twoStarShotLimit: 2,
                threeStarRequiresNoPowerups: true,
                threeStarShotLimit: 1
            ),
            shotLimit: shotLimit
        )
    }

    private func powerupLevel(
        columns: Int = 3,
        rows: Int = 4,
        missionHitPoints: Int = 1,
        bricks: [BrickDefinition]? = nil,
        shieldLinks: [ShieldLink] = []
    ) -> LevelDefinition {
        LevelDefinition(
            id: "powerups",
            title: "Powerups",
            columns: columns,
            rows: rows,
            bricks: bricks ?? [
                brick("mission", row: 0, column: 1, kind: .mission, hitPoints: missionHitPoints)
            ],
            availablePowerups: [.extraBalls, .shieldBreaker, .precisionGuide, .bomb, .rowClear],
            maxPowerupLoadoutSize: 2,
            starRules: StarRules(
                twoStarShotLimit: 3,
                threeStarRequiresNoPowerups: true,
                threeStarShotLimit: 2
            ),
            shieldLinks: shieldLinks
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
}

@Suite("Game performance")
struct GamePerformanceTests {
    @Test("High-ball-count shots stay within the prototype budget")
    func highBallCountShotPerformance() throws {
        let baseline = try resolveStressShot()
        #expect(baseline.frames.map { $0.balls.count }.max() ?? 0 >= 6)
        #expect(baseline.finalSnapshot.terminalReason != .simulationLimitReached)

        let clock = ContinuousClock()
        let elapsed = try clock.measure {
            for _ in 0..<25 {
                _ = try resolveStressShot()
            }
        }
        #expect(elapsed < .seconds(2), "25 stress shots took \(elapsed)")
    }

    private func resolveStressShot() throws -> ShotResolution {
        let level = LevelDefinition(
            id: "performance-stress",
            title: "Performance Stress",
            columns: 9,
            rows: 10,
            bricks: [
                BrickDefinition(id: "mission", row: 0, column: 4, kind: .mission, hitPoints: 50),
                BrickDefinition(id: "splitter-low", row: 7, column: 4, kind: .splitter, hitPoints: 1),
                BrickDefinition(id: "splitter-mid", row: 5, column: 4, kind: .splitter, hitPoints: 1),
                BrickDefinition(id: "splitter-high", row: 3, column: 4, kind: .splitter, hitPoints: 1),
                BrickDefinition(id: "rail-left", row: 4, column: 2, kind: .standard, hitPoints: 10),
                BrickDefinition(id: "rail-right", row: 4, column: 6, kind: .standard, hitPoints: 10)
            ],
            availablePowerups: [.extraBalls],
            maxPowerupLoadoutSize: 1,
            starRules: StarRules(
                twoStarShotLimit: 4,
                threeStarRequiresNoPowerups: true,
                threeStarShotLimit: 3
            ),
            metadata: LevelAuthoringMetadata(
                intendedSolution: "Performance-only stress fixture.",
                minimumKnownShotCount: 1,
                requiredMechanics: [.aiming, .missionObjective, .splitters],
                difficulty: .hard,
                validationStatus: .draft
            )
        )
        var state = try GameState(
            level: level,
            loadout: PowerupLoadout(selectedPowerups: [.extraBalls])
        )
        try state.activatePowerup(.extraBalls)
        try state.beginAiming()
        try state.updateAim(angleDegrees: 90)
        return try state.fire()
    }
}
