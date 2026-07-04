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
            bricks: level.bricks.map(BrickState.init(definition:)),
            balls: []
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
