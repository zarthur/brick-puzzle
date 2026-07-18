import Foundation

struct BoardCoordinate: Codable, Hashable {
    let row: Int
    let column: Int

    func isValid(in boardSize: BoardSize) -> Bool {
        (0..<boardSize.rows).contains(row) && (0..<boardSize.columns).contains(column)
    }
}

struct BoardSize: Codable, Hashable {
    let columns: Int
    let rows: Int
}

struct BoardPoint: Codable, Hashable {
    var x: Double
    var y: Double
}

struct BoardVector: Codable, Hashable {
    var dx: Double
    var dy: Double

    func rotated(byDegrees degrees: Double) -> BoardVector {
        let radians = degrees * .pi / 180
        return BoardVector(
            dx: dx * cos(radians) - dy * sin(radians),
            dy: dx * sin(radians) + dy * cos(radians)
        )
    }
}

struct BoardRect: Codable, Hashable {
    let minX: Double
    let minY: Double
    let maxX: Double
    let maxY: Double

    func intersectsCircle(center: BoardPoint, radius: Double) -> Bool {
        let closestX = min(max(center.x, minX), maxX)
        let closestY = min(max(center.y, minY), maxY)
        let dx = center.x - closestX
        let dy = center.y - closestY
        return dx * dx + dy * dy <= radius * radius
    }
}

/// Board-space coordinates use cells as units, with (0, 0) at the board's
/// bottom-left. Level rows remain authored from top to bottom.
struct BoardGeometry: Codable, Hashable {
    let size: BoardSize

    var launcherPosition: BoardPoint {
        BoardPoint(x: Double(size.columns) / 2, y: -0.65)
    }

    func brickBounds(at coordinate: BoardCoordinate) -> BoardRect? {
        guard coordinate.isValid(in: size) else {
            return nil
        }
        let minY = Double(size.rows - coordinate.row - 1)
        return BoardRect(
            minX: Double(coordinate.column),
            minY: minY,
            maxX: Double(coordinate.column + 1),
            maxY: minY + 1
        )
    }
}

struct BrickState: Codable, Hashable, Identifiable {
    let id: String
    let coordinate: BoardCoordinate
    let kind: BrickKind
    var hitPoints: Int
    var isDestroyed: Bool
    var protectionSourceIDs: [String]
    var lockSourceIDs: [String]

    var isProtected: Bool {
        !protectionSourceIDs.isEmpty
    }

    var isLocked: Bool {
        !lockSourceIDs.isEmpty
    }
}

struct BallState: Codable, Hashable, Identifiable {
    let id: String
    var position: BoardPoint
    var velocity: BoardVector
    var isActive: Bool
}

enum TurnPhase: String, Codable, Hashable {
    case idle
    case aiming
    case resolving
    case won
    case failed
}

enum TerminalReason: String, Codable, Hashable {
    case objectiveCompleted
    case shotLimitReached
    case dangerLineCrossed
    case simulationLimitReached
}

struct ObjectiveProgress: Codable, Hashable {
    let orderedBrickIDs: [String]
    var completedBrickIDs: [String]
    var nextStepIndex: Int
    var wasCompletedOutOfOrder: Bool

    var nextRequiredBrickID: String? {
        orderedBrickIDs.indices.contains(nextStepIndex) ? orderedBrickIDs[nextStepIndex] : nil
    }
}

enum GameplayEventKind: String, Codable, Hashable {
    case brickDamaged
    case brickDestroyed
    case damageBlocked
    case shieldRemoved
    case targetUnlocked
    case bombTriggered
    case ballsSplit
    case objectiveStepCompleted
    case objectiveOrderViolated
}

struct GameplayEvent: Codable, Hashable {
    let kind: GameplayEventKind
    let subjectID: String
    let relatedIDs: [String]
}

struct GameSnapshot: Codable, Hashable {
    let levelID: String
    let levelTitle: String
    let boardSize: BoardSize
    let objective: LevelObjective
    let objectiveProgress: ObjectiveProgress
    let turnPhase: TurnPhase
    let terminalReason: TerminalReason?
    let shotCount: Int
    let aimAngleDegrees: Double?
    let shotHistory: [ShotRecord]
    let usedPowerups: [PowerupDefinition]
    let bricks: [BrickState]
    let balls: [BallState]

    var activeBricks: [BrickState] {
        bricks.filter { !$0.isDestroyed }
    }

    var missionBrickCount: Int {
        activeBricks.filter { $0.kind == .mission }.count
    }
}

struct BallFrame: Codable, Hashable, Identifiable {
    let id: String
    let position: BoardPoint
}

struct ShotFrame: Codable, Hashable {
    let elapsedTime: Double
    let balls: [BallFrame]

    /// Compatibility convenience for single-ball callers and tests.
    var position: BoardPoint {
        balls.first?.position ?? BoardPoint(x: 0, y: -2)
    }
}

struct ShotRecord: Codable, Hashable {
    let aimAngleDegrees: Double
    let damagedBrickIDs: [String]
    let destroyedBrickIDs: [String]
    let events: [GameplayEvent]
}

struct ShotResolution: Codable, Hashable {
    let frames: [ShotFrame]
    let finalSnapshot: GameSnapshot
}

enum GameInputError: Error, Equatable {
    case invalidPhase
    case invalidAim
}

enum DamageSource: String, Codable, Hashable {
    case ball
    case bomb
    case powerup
    case replay
}

struct GameSimulationConfiguration: Codable, Hashable {
    let ballRadius: Double
    let ballSpeed: Double
    let fixedTimeStep: Double
    let maximumSteps: Int
    let animationSampleStride: Int
    let maximumActiveBalls: Int
    let splitterAngleOffsetDegrees: Double

    static let prototype = GameSimulationConfiguration(
        ballRadius: 0.12,
        ballSpeed: 7,
        fixedTimeStep: 1.0 / 120.0,
        maximumSteps: 2_400,
        animationSampleStride: 2,
        maximumActiveBalls: 8,
        splitterAngleOffsetDegrees: 18
    )
}

struct GameState: Codable, Hashable {
    private(set) var snapshot: GameSnapshot
    private let shotLimit: Int?
    private let dangerLineRow: Int?
    private let objectiveDefinition: ObjectiveDefinition
    private let shieldLinks: [ShieldLink]
    private let keyLinks: [KeyLink]
    private let simulation: GameSimulationConfiguration

    var configuredDangerLineRow: Int? {
        dangerLineRow
    }

    init(
        level: LevelDefinition,
        simulation: GameSimulationConfiguration = .prototype
    ) {
        shotLimit = level.shotLimit
        dangerLineRow = level.dangerLineRow
        objectiveDefinition = level.objective
        shieldLinks = level.shieldLinks
        keyLinks = level.keyLinks
        self.simulation = simulation

        var bricks = level.bricks.map(BrickState.init(definition:))
        for link in level.shieldLinks {
            for targetID in link.protectedBrickIDs {
                guard let targetIndex = bricks.firstIndex(where: { $0.id == targetID }) else { continue }
                bricks[targetIndex].protectionSourceIDs.append(link.shieldID)
            }
        }
        for link in level.keyLinks {
            for targetID in link.lockedBrickIDs {
                guard let targetIndex = bricks.firstIndex(where: { $0.id == targetID }) else { continue }
                bricks[targetIndex].lockSourceIDs.append(link.keyID)
            }
        }
        for index in bricks.indices {
            bricks[index].protectionSourceIDs = Array(Set(bricks[index].protectionSourceIDs)).sorted()
            bricks[index].lockSourceIDs = Array(Set(bricks[index].lockSourceIDs)).sorted()
        }

        let hasMissionBricks = bricks.contains { $0.kind == .mission && !$0.isDestroyed }
        snapshot = GameSnapshot(
            levelID: level.id,
            levelTitle: level.title,
            boardSize: BoardSize(columns: level.columns, rows: level.rows),
            objective: level.objective.kind,
            objectiveProgress: ObjectiveProgress(
                orderedBrickIDs: level.objective.orderedBrickIDs,
                completedBrickIDs: [],
                nextStepIndex: 0,
                wasCompletedOutOfOrder: false
            ),
            turnPhase: hasMissionBricks ? .idle : .won,
            terminalReason: hasMissionBricks ? nil : .objectiveCompleted,
            shotCount: 0,
            aimAngleDegrees: nil,
            shotHistory: [],
            usedPowerups: [],
            bricks: bricks,
            balls: []
        )
    }

    mutating func beginAiming() throws {
        guard snapshot.turnPhase == .idle else {
            throw GameInputError.invalidPhase
        }
        replaceSnapshot(turnPhase: .aiming, aimAngleDegrees: 90)
    }

    mutating func updateAim(angleDegrees: Double) throws {
        guard snapshot.turnPhase == .aiming else {
            throw GameInputError.invalidPhase
        }
        guard Self.isValidAim(angleDegrees) else {
            throw GameInputError.invalidAim
        }
        replaceSnapshot(turnPhase: .aiming, aimAngleDegrees: angleDegrees)
    }

    mutating func cancelAim() throws {
        guard snapshot.turnPhase == .aiming else {
            throw GameInputError.invalidPhase
        }
        replaceSnapshot(turnPhase: .idle, clearsAim: true)
    }

    mutating func fire() throws -> ShotResolution {
        guard snapshot.turnPhase == .aiming else {
            throw GameInputError.invalidPhase
        }
        guard let angle = snapshot.aimAngleDegrees, Self.isValidAim(angle) else {
            throw GameInputError.invalidAim
        }

        let geometry = BoardGeometry(size: snapshot.boardSize)
        let radians = angle * .pi / 180
        let shotNumber = snapshot.shotCount + 1
        var balls = [BallState(
            id: "shot-\(shotNumber)-ball-1",
            position: geometry.launcherPosition,
            velocity: BoardVector(
                dx: cos(radians) * simulation.ballSpeed,
                dy: sin(radians) * simulation.ballSpeed
            ),
            isActive: true
        )]
        var bricks = snapshot.bricks
        var objectiveProgress = snapshot.objectiveProgress
        var frames = [makeFrame(elapsedTime: 0, balls: balls)]
        var events: [GameplayEvent] = []
        var triggeredBombIDs: Set<String> = []
        var triggeredSplitterIDs: Set<String> = []
        var nextSpawnID = 1

        replaceSnapshot(
            turnPhase: .resolving,
            shotCount: shotNumber,
            aimAngleDegrees: angle,
            bricks: bricks,
            balls: balls
        )

        var reachedSimulationLimit = true
        for step in 1...simulation.maximumSteps {
            var spawnedBalls: [BallState] = []
            var hadCollision = false
            let activeIndices = balls.indices.filter { balls[$0].isActive }

            for index in activeIndices {
                let previousPosition = balls[index].position
                balls[index].position.x += balls[index].velocity.dx * simulation.fixedTimeStep
                balls[index].position.y += balls[index].velocity.dy * simulation.fixedTimeStep
                resolveWallCollisions(ball: &balls[index], boardSize: snapshot.boardSize)

                if let collision = resolveBrickCollision(
                    ball: &balls[index],
                    previousPosition: previousPosition,
                    bricks: &bricks,
                    geometry: geometry,
                    objectiveProgress: &objectiveProgress,
                    events: &events,
                    triggeredBombIDs: &triggeredBombIDs
                ) {
                    hadCollision = true
                    if collision.kind == .splitter,
                       collision.didDamage,
                       triggeredSplitterIDs.insert(collision.brickID).inserted {
                        let availableSlots = max(0, simulation.maximumActiveBalls - balls.filter(\.isActive).count - spawnedBalls.count)
                        let spawnCount = min(2, availableSlots)
                        for offset in [
                            -simulation.splitterAngleOffsetDegrees,
                            simulation.splitterAngleOffsetDegrees
                        ].prefix(spawnCount) {
                            let id = "shot-\(shotNumber)-split-\(nextSpawnID)"
                            nextSpawnID += 1
                            spawnedBalls.append(BallState(
                                id: id,
                                position: balls[index].position,
                                velocity: balls[index].velocity.rotated(byDegrees: offset),
                                isActive: true
                            ))
                        }
                        if !spawnedBalls.isEmpty {
                            events.append(GameplayEvent(
                                kind: .ballsSplit,
                                subjectID: collision.brickID,
                                relatedIDs: spawnedBalls.suffix(spawnCount).map(\.id)
                            ))
                        }
                    }
                }

                if balls[index].position.y < -1.05 {
                    balls[index].isActive = false
                }
            }

            balls.append(contentsOf: spawnedBalls)
            if step.isMultiple(of: simulation.animationSampleStride) || hadCollision || !spawnedBalls.isEmpty {
                frames.append(makeFrame(
                    elapsedTime: Double(step) * simulation.fixedTimeStep,
                    balls: balls
                ))
            }

            if !balls.contains(where: \.isActive) {
                reachedSimulationLimit = false
                frames.append(makeFrame(
                    elapsedTime: Double(step) * simulation.fixedTimeStep,
                    balls: balls
                ))
                break
            }
        }

        let terminal = terminalState(
            bricks: bricks,
            shotCount: shotNumber,
            reachedSimulationLimit: reachedSimulationLimit
        )
        let damagedIDs = events.filter { $0.kind == .brickDamaged }.map(\.subjectID)
        let destroyedIDs = events.filter { $0.kind == .brickDestroyed }.map(\.subjectID)
        replaceSnapshot(
            turnPhase: terminal.phase,
            terminalReason: terminal.reason,
            clearsAim: true,
            objectiveProgress: objectiveProgress,
            shotHistory: snapshot.shotHistory + [ShotRecord(
                aimAngleDegrees: angle,
                damagedBrickIDs: damagedIDs,
                destroyedBrickIDs: destroyedIDs,
                events: events
            )],
            bricks: bricks,
            balls: []
        )
        return ShotResolution(frames: frames, finalSnapshot: snapshot)
    }

    /// Shared entry point for future powerups and deterministic mechanics tests.
    @discardableResult
    mutating func applyDamage(
        to brickID: String,
        amount: Int = 1,
        source: DamageSource = .powerup
    ) -> [GameplayEvent] {
        guard amount > 0 else { return [] }
        var bricks = snapshot.bricks
        var objectiveProgress = snapshot.objectiveProgress
        var events: [GameplayEvent] = []
        var triggeredBombIDs: Set<String> = []
        _ = resolveDamageQueue(
            initial: PendingDamage(targetID: brickID, amount: amount, source: source),
            bricks: &bricks,
            objectiveProgress: &objectiveProgress,
            events: &events,
            triggeredBombIDs: &triggeredBombIDs
        )
        let terminal = terminalState(
            bricks: bricks,
            shotCount: snapshot.shotCount,
            reachedSimulationLimit: false
        )
        replaceSnapshot(
            turnPhase: terminal.phase,
            terminalReason: terminal.reason,
            objectiveProgress: objectiveProgress,
            bricks: bricks
        )
        return events
    }

    static func isValidAim(_ angleDegrees: Double) -> Bool {
        angleDegrees.isFinite && (15...165).contains(angleDegrees)
    }

    mutating func applyPlaceholderShot(
        destroyedBrickIDs: [String],
        aimAngleDegrees: Double = 90,
        usedPowerups: [PowerupDefinition] = []
    ) {
        guard snapshot.turnPhase != .won, snapshot.turnPhase != .failed else { return }
        let destroyedIDs = Set(destroyedBrickIDs)
        var bricks = snapshot.bricks
        var objectiveProgress = snapshot.objectiveProgress
        var events: [GameplayEvent] = []

        for index in bricks.indices where destroyedIDs.contains(bricks[index].id) {
            bricks[index].hitPoints = 0
            bricks[index].isDestroyed = true
            events.append(GameplayEvent(kind: .brickDestroyed, subjectID: bricks[index].id, relatedIDs: []))
            updateObjectiveProgress(
                destroyedBrickID: bricks[index].id,
                progress: &objectiveProgress,
                events: &events
            )
        }

        let allUsedPowerups = Set(snapshot.usedPowerups + usedPowerups)
            .sorted { $0.rawValue < $1.rawValue }
        let shotCount = snapshot.shotCount + 1
        let terminal = terminalState(
            bricks: bricks,
            shotCount: shotCount,
            reachedSimulationLimit: false
        )
        replaceSnapshot(
            turnPhase: terminal.phase,
            terminalReason: terminal.reason,
            shotCount: shotCount,
            clearsAim: true,
            objectiveProgress: objectiveProgress,
            shotHistory: snapshot.shotHistory + [ShotRecord(
                aimAngleDegrees: aimAngleDegrees,
                damagedBrickIDs: destroyedBrickIDs,
                destroyedBrickIDs: destroyedBrickIDs,
                events: events
            )],
            usedPowerups: allUsedPowerups,
            bricks: bricks,
            balls: []
        )
    }

    private func makeFrame(elapsedTime: Double, balls: [BallState]) -> ShotFrame {
        ShotFrame(
            elapsedTime: elapsedTime,
            balls: balls.sorted { $0.id < $1.id }.map {
                BallFrame(id: $0.id, position: $0.position)
            }
        )
    }

    private func resolveWallCollisions(ball: inout BallState, boardSize: BoardSize) {
        let radius = simulation.ballRadius
        let maxX = Double(boardSize.columns)
        let maxY = Double(boardSize.rows)
        if ball.position.x - radius < 0 {
            ball.position.x = radius
            ball.velocity.dx = abs(ball.velocity.dx)
        } else if ball.position.x + radius > maxX {
            ball.position.x = maxX - radius
            ball.velocity.dx = -abs(ball.velocity.dx)
        }
        if ball.position.y + radius > maxY {
            ball.position.y = maxY - radius
            ball.velocity.dy = -abs(ball.velocity.dy)
        }
    }

    private func resolveBrickCollision(
        ball: inout BallState,
        previousPosition: BoardPoint,
        bricks: inout [BrickState],
        geometry: BoardGeometry,
        objectiveProgress: inout ObjectiveProgress,
        events: inout [GameplayEvent],
        triggeredBombIDs: inout Set<String>
    ) -> CollisionResult? {
        guard let index = bricks.indices.first(where: { index in
            guard !bricks[index].isDestroyed,
                  let bounds = geometry.brickBounds(at: bricks[index].coordinate) else { return false }
            return bounds.intersectsCircle(center: ball.position, radius: simulation.ballRadius)
        }), let bounds = geometry.brickBounds(at: bricks[index].coordinate) else { return nil }

        let brickID = bricks[index].id
        let kind = bricks[index].kind
        let didDamage = resolveDamageQueue(
            initial: PendingDamage(targetID: brickID, amount: 1, source: .ball),
            bricks: &bricks,
            objectiveProgress: &objectiveProgress,
            events: &events,
            triggeredBombIDs: &triggeredBombIDs
        )

        if previousPosition.y <= bounds.minY || previousPosition.y >= bounds.maxY {
            ball.velocity.dy *= -1
            ball.position.y = previousPosition.y
        } else {
            ball.velocity.dx *= -1
            ball.position.x = previousPosition.x
        }
        return CollisionResult(brickID: brickID, kind: kind, didDamage: didDamage)
    }

    @discardableResult
    private func resolveDamageQueue(
        initial: PendingDamage,
        bricks: inout [BrickState],
        objectiveProgress: inout ObjectiveProgress,
        events: inout [GameplayEvent],
        triggeredBombIDs: inout Set<String>
    ) -> Bool {
        var queue = [initial]
        var initialDidDamage = false
        var isFirst = true

        while !queue.isEmpty {
            let pending = queue.removeFirst()
            guard let index = bricks.firstIndex(where: { $0.id == pending.targetID }),
                  !bricks[index].isDestroyed else {
                isFirst = false
                continue
            }

            if pending.source != .replay, bricks[index].isProtected || bricks[index].isLocked {
                events.append(GameplayEvent(
                    kind: .damageBlocked,
                    subjectID: bricks[index].id,
                    relatedIDs: bricks[index].protectionSourceIDs + bricks[index].lockSourceIDs
                ))
                isFirst = false
                continue
            }

            bricks[index].hitPoints = max(0, bricks[index].hitPoints - pending.amount)
            events.append(GameplayEvent(kind: .brickDamaged, subjectID: bricks[index].id, relatedIDs: []))
            if isFirst { initialDidDamage = true }

            guard bricks[index].hitPoints == 0 else {
                isFirst = false
                continue
            }

            bricks[index].isDestroyed = true
            let destroyedBrick = bricks[index]
            events.append(GameplayEvent(kind: .brickDestroyed, subjectID: destroyedBrick.id, relatedIDs: []))
            updateObjectiveProgress(
                destroyedBrickID: destroyedBrick.id,
                progress: &objectiveProgress,
                events: &events
            )

            if destroyedBrick.kind == .shield {
                for link in shieldLinks.filter({ $0.shieldID == destroyedBrick.id }) {
                    for targetID in link.protectedBrickIDs.sorted() {
                        guard let targetIndex = bricks.firstIndex(where: { $0.id == targetID }) else { continue }
                        bricks[targetIndex].protectionSourceIDs.removeAll { $0 == destroyedBrick.id }
                        events.append(GameplayEvent(
                            kind: .shieldRemoved,
                            subjectID: destroyedBrick.id,
                            relatedIDs: [targetID]
                        ))
                    }
                }
            }

            if destroyedBrick.kind == .key {
                for link in keyLinks.filter({ $0.keyID == destroyedBrick.id }) {
                    for targetID in link.lockedBrickIDs.sorted() {
                        guard let targetIndex = bricks.firstIndex(where: { $0.id == targetID }) else { continue }
                        bricks[targetIndex].lockSourceIDs.removeAll { $0 == destroyedBrick.id }
                        events.append(GameplayEvent(
                            kind: .targetUnlocked,
                            subjectID: destroyedBrick.id,
                            relatedIDs: [targetID]
                        ))
                    }
                }
            }

            if destroyedBrick.kind == .bomb,
               triggeredBombIDs.insert(destroyedBrick.id).inserted {
                let neighborIDs = bricks.filter { candidate in
                    guard !candidate.isDestroyed, candidate.id != destroyedBrick.id else { return false }
                    return abs(candidate.coordinate.row - destroyedBrick.coordinate.row) <= 1
                        && abs(candidate.coordinate.column - destroyedBrick.coordinate.column) <= 1
                }.map(\.id).sorted()
                events.append(GameplayEvent(
                    kind: .bombTriggered,
                    subjectID: destroyedBrick.id,
                    relatedIDs: neighborIDs
                ))
                queue.append(contentsOf: neighborIDs.map {
                    PendingDamage(targetID: $0, amount: 1, source: .bomb)
                })
            }
            isFirst = false
        }
        return initialDidDamage
    }

    private func updateObjectiveProgress(
        destroyedBrickID: String,
        progress: inout ObjectiveProgress,
        events: inout [GameplayEvent]
    ) {
        guard !progress.orderedBrickIDs.isEmpty,
              progress.orderedBrickIDs.contains(destroyedBrickID) else { return }

        if progress.nextRequiredBrickID == destroyedBrickID {
            progress.completedBrickIDs.append(destroyedBrickID)
            progress.nextStepIndex += 1
            events.append(GameplayEvent(
                kind: .objectiveStepCompleted,
                subjectID: destroyedBrickID,
                relatedIDs: []
            ))
        } else if !progress.completedBrickIDs.contains(destroyedBrickID) {
            progress.wasCompletedOutOfOrder = true
            events.append(GameplayEvent(
                kind: .objectiveOrderViolated,
                subjectID: destroyedBrickID,
                relatedIDs: [progress.nextRequiredBrickID].compactMap { $0 }
            ))
        }
    }

    private func terminalState(
        bricks: [BrickState],
        shotCount: Int,
        reachedSimulationLimit: Bool
    ) -> (phase: TurnPhase, reason: TerminalReason?) {
        let hasMissionBricks = bricks.contains { $0.kind == .mission && !$0.isDestroyed }
        if objectiveDefinition.kind == .clearMissionBricks, !hasMissionBricks {
            return (.won, .objectiveCompleted)
        }
        if reachedSimulationLimit { return (.failed, .simulationLimitReached) }
        if let dangerLineRow,
           bricks.contains(where: { !$0.isDestroyed && $0.coordinate.row >= dangerLineRow }) {
            return (.failed, .dangerLineCrossed)
        }
        if let shotLimit, shotCount >= shotLimit { return (.failed, .shotLimitReached) }
        return (.idle, nil)
    }

    private mutating func replaceSnapshot(
        turnPhase: TurnPhase? = nil,
        terminalReason: TerminalReason? = nil,
        shotCount: Int? = nil,
        aimAngleDegrees: Double? = nil,
        clearsAim: Bool = false,
        objectiveProgress: ObjectiveProgress? = nil,
        shotHistory: [ShotRecord]? = nil,
        usedPowerups: [PowerupDefinition]? = nil,
        bricks: [BrickState]? = nil,
        balls: [BallState]? = nil
    ) {
        snapshot = GameSnapshot(
            levelID: snapshot.levelID,
            levelTitle: snapshot.levelTitle,
            boardSize: snapshot.boardSize,
            objective: snapshot.objective,
            objectiveProgress: objectiveProgress ?? snapshot.objectiveProgress,
            turnPhase: turnPhase ?? snapshot.turnPhase,
            terminalReason: terminalReason,
            shotCount: shotCount ?? snapshot.shotCount,
            aimAngleDegrees: clearsAim ? nil : (aimAngleDegrees ?? snapshot.aimAngleDegrees),
            shotHistory: shotHistory ?? snapshot.shotHistory,
            usedPowerups: usedPowerups ?? snapshot.usedPowerups,
            bricks: bricks ?? snapshot.bricks,
            balls: balls ?? snapshot.balls
        )
    }
}

private struct PendingDamage {
    let targetID: String
    let amount: Int
    let source: DamageSource
}

private struct CollisionResult {
    let brickID: String
    let kind: BrickKind
    let didDamage: Bool
}

private extension BrickState {
    init(definition: BrickDefinition) {
        self.init(
            id: definition.id,
            coordinate: BoardCoordinate(row: definition.row, column: definition.column),
            kind: definition.kind,
            hitPoints: definition.hitPoints,
            isDestroyed: false,
            protectionSourceIDs: [],
            lockSourceIDs: []
        )
    }
}
