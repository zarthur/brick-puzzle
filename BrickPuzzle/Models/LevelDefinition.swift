import Foundation

enum LevelObjective: String, Codable, Hashable {
    case clearMissionBricks
}

struct ObjectiveDefinition: Codable, Hashable {
    let kind: LevelObjective
    let orderedBrickIDs: [String]

    static let clearMissionBricks = ObjectiveDefinition(
        kind: .clearMissionBricks,
        orderedBrickIDs: []
    )
}

struct ShieldLink: Codable, Hashable {
    let shieldID: String
    let protectedBrickIDs: [String]
}

struct KeyLink: Codable, Hashable {
    let keyID: String
    let lockedBrickIDs: [String]
}

struct LevelDefinition: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let columns: Int
    let rows: Int
    let bricks: [BrickDefinition]
    let availablePowerups: [PowerupDefinition]
    let maxPowerupLoadoutSize: Int
    let starRules: StarRules
    let shotLimit: Int?
    let dangerLineRow: Int?
    let objective: ObjectiveDefinition
    let shieldLinks: [ShieldLink]
    let keyLinks: [KeyLink]

    init(
        id: String,
        title: String,
        columns: Int,
        rows: Int,
        bricks: [BrickDefinition],
        availablePowerups: [PowerupDefinition],
        maxPowerupLoadoutSize: Int,
        starRules: StarRules,
        shotLimit: Int? = nil,
        dangerLineRow: Int? = nil,
        objective: ObjectiveDefinition = .clearMissionBricks,
        shieldLinks: [ShieldLink] = [],
        keyLinks: [KeyLink] = []
    ) {
        self.id = id
        self.title = title
        self.columns = columns
        self.rows = rows
        self.bricks = bricks
        self.availablePowerups = availablePowerups
        self.maxPowerupLoadoutSize = maxPowerupLoadoutSize
        self.starRules = starRules
        self.shotLimit = shotLimit
        self.dangerLineRow = dangerLineRow
        self.objective = objective
        self.shieldLinks = shieldLinks
        self.keyLinks = keyLinks
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, columns, rows, bricks, availablePowerups
        case maxPowerupLoadoutSize, starRules, shotLimit, dangerLineRow
        case objective, shieldLinks, keyLinks
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        columns = try container.decode(Int.self, forKey: .columns)
        rows = try container.decode(Int.self, forKey: .rows)
        bricks = try container.decode([BrickDefinition].self, forKey: .bricks)
        availablePowerups = try container.decode([PowerupDefinition].self, forKey: .availablePowerups)
        maxPowerupLoadoutSize = try container.decode(Int.self, forKey: .maxPowerupLoadoutSize)
        starRules = try container.decode(StarRules.self, forKey: .starRules)
        shotLimit = try container.decodeIfPresent(Int.self, forKey: .shotLimit)
        dangerLineRow = try container.decodeIfPresent(Int.self, forKey: .dangerLineRow)
        objective = try container.decodeIfPresent(ObjectiveDefinition.self, forKey: .objective)
            ?? .clearMissionBricks
        shieldLinks = try container.decodeIfPresent([ShieldLink].self, forKey: .shieldLinks) ?? []
        keyLinks = try container.decodeIfPresent([KeyLink].self, forKey: .keyLinks) ?? []
    }
}

struct BrickDefinition: Codable, Hashable, Identifiable {
    let id: String
    let row: Int
    let column: Int
    let kind: BrickKind
    let hitPoints: Int

    init(
        id: String? = nil,
        row: Int,
        column: Int,
        kind: BrickKind,
        hitPoints: Int
    ) {
        self.id = id ?? "\(row)-\(column)-\(kind.rawValue)"
        self.row = row
        self.column = column
        self.kind = kind
        self.hitPoints = hitPoints
    }

    private enum CodingKeys: String, CodingKey {
        case id, row, column, kind, hitPoints
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        row = try container.decode(Int.self, forKey: .row)
        column = try container.decode(Int.self, forKey: .column)
        kind = try container.decode(BrickKind.self, forKey: .kind)
        hitPoints = try container.decode(Int.self, forKey: .hitPoints)
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? "\(row)-\(column)-\(kind.rawValue)"
    }
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
            BrickDefinition(id: "shield-left", row: 0, column: 2, kind: .shield, hitPoints: 3),
            BrickDefinition(id: "mission-core", row: 0, column: 3, kind: .mission, hitPoints: 4),
            BrickDefinition(id: "shield-right", row: 0, column: 4, kind: .shield, hitPoints: 3),
            BrickDefinition(id: "standard-left", row: 1, column: 1, kind: .standard, hitPoints: 2),
            BrickDefinition(id: "key-core", row: 1, column: 3, kind: .key, hitPoints: 1),
            BrickDefinition(id: "standard-right", row: 1, column: 5, kind: .standard, hitPoints: 2),
            BrickDefinition(id: "bomb-left", row: 2, column: 0, kind: .bomb, hitPoints: 1),
            BrickDefinition(id: "center-block", row: 2, column: 3, kind: .standard, hitPoints: 3),
            BrickDefinition(id: "splitter-right", row: 2, column: 6, kind: .splitter, hitPoints: 1),
            BrickDefinition(id: "standard-lower-left", row: 3, column: 2, kind: .standard, hitPoints: 2),
            BrickDefinition(id: "standard-lower-right", row: 3, column: 4, kind: .standard, hitPoints: 2)
        ],
        availablePowerups: [.extraBalls, .shieldBreaker, .precisionGuide],
        maxPowerupLoadoutSize: 2,
        starRules: StarRules(
            twoStarShotLimit: 4,
            threeStarRequiresNoPowerups: true,
            threeStarShotLimit: 3
        ),
        objective: ObjectiveDefinition(
            kind: .clearMissionBricks,
            orderedBrickIDs: ["key-core", "mission-core"]
        ),
        shieldLinks: [
            ShieldLink(shieldID: "shield-left", protectedBrickIDs: ["mission-core"]),
            ShieldLink(shieldID: "shield-right", protectedBrickIDs: ["mission-core"])
        ],
        keyLinks: [
            KeyLink(keyID: "key-core", lockedBrickIDs: ["center-block"])
        ]
    )
}
