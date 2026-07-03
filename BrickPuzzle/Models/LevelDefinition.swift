import Foundation

struct LevelDefinition: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let columns: Int
    let rows: Int
    let bricks: [BrickDefinition]
    let availablePowerups: [PowerupDefinition]
    let maxPowerupLoadoutSize: Int
    let starRules: StarRules
}

struct BrickDefinition: Codable, Hashable, Identifiable {
    var id: String {
        "\(row)-\(column)-\(kind.rawValue)"
    }

    let row: Int
    let column: Int
    let kind: BrickKind
    let hitPoints: Int
}

enum BrickKind: String, Codable, CaseIterable, Hashable {
    case standard
    case mission
    case shield
    case key
    case bomb
    case splitter
}

struct StarRules: Codable, Hashable {
    let twoStarShotLimit: Int
    let threeStarRequiresNoPowerups: Bool
    let threeStarShotLimit: Int
}

extension LevelDefinition {
    static let prototype = LevelDefinition(
        id: "prototype-001",
        title: "Prototype Level",
        columns: 7,
        rows: 8,
        bricks: [
            BrickDefinition(row: 0, column: 2, kind: .shield, hitPoints: 3),
            BrickDefinition(row: 0, column: 3, kind: .mission, hitPoints: 4),
            BrickDefinition(row: 0, column: 4, kind: .shield, hitPoints: 3),
            BrickDefinition(row: 1, column: 1, kind: .standard, hitPoints: 2),
            BrickDefinition(row: 1, column: 3, kind: .key, hitPoints: 1),
            BrickDefinition(row: 1, column: 5, kind: .standard, hitPoints: 2),
            BrickDefinition(row: 2, column: 0, kind: .bomb, hitPoints: 1),
            BrickDefinition(row: 2, column: 3, kind: .standard, hitPoints: 3),
            BrickDefinition(row: 2, column: 6, kind: .splitter, hitPoints: 1),
            BrickDefinition(row: 3, column: 2, kind: .standard, hitPoints: 2),
            BrickDefinition(row: 3, column: 4, kind: .standard, hitPoints: 2)
        ],
        availablePowerups: [.extraBalls, .shieldBreaker, .precisionGuide],
        maxPowerupLoadoutSize: 2,
        starRules: StarRules(
            twoStarShotLimit: 4,
            threeStarRequiresNoPowerups: true,
            threeStarShotLimit: 3
        )
    )
}

