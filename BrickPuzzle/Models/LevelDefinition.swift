import Foundation

enum LevelObjective: String, Codable, Hashable {
    case clearMissionBricks
}

enum LevelMechanic: String, Codable, CaseIterable, Hashable {
    case aiming
    case standardDamage
    case missionObjective
    case starScoring
    case keyOrdering
    case shields
    case bombs
    case splitters
}

enum LevelDifficulty: String, Codable, CaseIterable, Hashable {
    case tutorial
    case easy
    case medium
    case hard
}

enum LevelValidationStatus: String, Codable, CaseIterable, Hashable {
    case draft
    case replayValidated
}

struct LevelAuthoringMetadata: Codable, Hashable {
    let intendedSolution: String
    let minimumKnownShotCount: Int
    let requiredMechanics: [LevelMechanic]
    let difficulty: LevelDifficulty
    let validationStatus: LevelValidationStatus

    func validate(for levelID: String) throws {
        guard !intendedSolution.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LevelMetadataError.emptyIntendedSolution(levelID: levelID)
        }
        guard minimumKnownShotCount > 0 else {
            throw LevelMetadataError.invalidMinimumShotCount(levelID: levelID)
        }
        guard !requiredMechanics.isEmpty else {
            throw LevelMetadataError.missingRequiredMechanics(levelID: levelID)
        }
    }
}

enum LevelMetadataError: Error, Equatable {
    case emptyIntendedSolution(levelID: String)
    case invalidMinimumShotCount(levelID: String)
    case missingRequiredMechanics(levelID: String)
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
    let metadata: LevelAuthoringMetadata

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
        keyLinks: [KeyLink] = [],
        metadata: LevelAuthoringMetadata = .prototype
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
        self.metadata = metadata
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, columns, rows, bricks, availablePowerups
        case maxPowerupLoadoutSize, starRules, shotLimit, dangerLineRow
        case objective, shieldLinks, keyLinks, metadata
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
        metadata = try container.decode(LevelAuthoringMetadata.self, forKey: .metadata)
        try metadata.validate(for: id)
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
        title: "First Shot",
        columns: 5,
        rows: 6,
        bricks: [
            BrickDefinition(id: "mission-center", row: 1, column: 2, kind: .mission, hitPoints: 1),
            BrickDefinition(id: "standard-left", row: 2, column: 1, kind: .standard, hitPoints: 1),
            BrickDefinition(id: "standard-right", row: 2, column: 3, kind: .standard, hitPoints: 1)
        ],
        availablePowerups: [.extraBalls, .precisionGuide],
        maxPowerupLoadoutSize: 1,
        starRules: StarRules(
            twoStarShotLimit: 2,
            threeStarRequiresNoPowerups: true,
            threeStarShotLimit: 1
        ),
        metadata: .prototype
    )
}

extension LevelAuthoringMetadata {
    static let prototype = LevelAuthoringMetadata(
        intendedSolution: "Aim through the center lane and break the mission brick in one shot.",
        minimumKnownShotCount: 1,
        requiredMechanics: [.aiming, .standardDamage, .missionObjective],
        difficulty: .tutorial,
        validationStatus: .replayValidated
    )
}
