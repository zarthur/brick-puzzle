import Foundation

struct BoardCoordinate: Codable, Hashable {
    let row: Int
    let column: Int
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
}

struct BrickState: Codable, Hashable, Identifiable {
    let id: String
    let coordinate: BoardCoordinate
    let kind: BrickKind
    let hitPoints: Int
    var isDestroyed: Bool
}

struct BallState: Codable, Hashable, Identifiable {
    let id: String
    var position: BoardPoint
    var velocity: BoardVector
    var isActive: Bool
}

enum LevelObjective: String, Codable, Hashable {
    case clearMissionBricks
}

enum TurnPhase: String, Codable, Hashable {
    case idle
    case aiming
    case resolving
    case won
    case failed
}

struct GameSnapshot: Codable, Hashable {
    let levelID: String
    let levelTitle: String
    let boardSize: BoardSize
    let objective: LevelObjective
    let turnPhase: TurnPhase
    let shotCount: Int
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

struct GameState: Codable, Hashable {
    private(set) var snapshot: GameSnapshot

    init(level: LevelDefinition) {
        snapshot = GameSnapshot(
            levelID: level.id,
            levelTitle: level.title,
            boardSize: BoardSize(columns: level.columns, rows: level.rows),
            objective: .clearMissionBricks,
            turnPhase: .idle,
            shotCount: 0,
            usedPowerups: [],
            bricks: level.bricks.map(BrickState.init(definition:)),
            balls: []
        )
    }

    mutating func applyPlaceholderShot(
        destroyedBrickIDs: [String],
        usedPowerups: [PowerupDefinition] = []
    ) {
        let destroyedIDs = Set(destroyedBrickIDs)
        var bricks = snapshot.bricks

        for index in bricks.indices where destroyedIDs.contains(bricks[index].id) {
            bricks[index].isDestroyed = true
        }

        let allUsedPowerups = Set(snapshot.usedPowerups + usedPowerups)
            .sorted { $0.rawValue < $1.rawValue }
        let hasRemainingMissionBricks = bricks.contains { brick in
            brick.kind == .mission && !brick.isDestroyed
        }

        snapshot = GameSnapshot(
            levelID: snapshot.levelID,
            levelTitle: snapshot.levelTitle,
            boardSize: snapshot.boardSize,
            objective: snapshot.objective,
            turnPhase: hasRemainingMissionBricks ? .idle : .won,
            shotCount: snapshot.shotCount + 1,
            usedPowerups: allUsedPowerups,
            bricks: bricks,
            balls: snapshot.balls
        )
    }
}

private extension BrickState {
    init(definition: BrickDefinition) {
        self.init(
            id: definition.id,
            coordinate: BoardCoordinate(row: definition.row, column: definition.column),
            kind: definition.kind,
            hitPoints: definition.hitPoints,
            isDestroyed: false
        )
    }
}
