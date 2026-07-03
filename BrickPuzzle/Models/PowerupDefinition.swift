import Foundation

enum PowerupDefinition: String, Codable, CaseIterable, Hashable, Identifiable {
    case extraBalls
    case shieldBreaker
    case precisionGuide
    case bomb
    case rowClear
    case gravityShift

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .extraBalls:
            return "Extra Balls"
        case .shieldBreaker:
            return "Shield Breaker"
        case .precisionGuide:
            return "Guide"
        case .bomb:
            return "Bomb"
        case .rowClear:
            return "Row Clear"
        case .gravityShift:
            return "Gravity Shift"
        }
    }
}

struct PowerupLoadout: Codable, Hashable {
    let selectedPowerups: [PowerupDefinition]

    func isValid(for level: LevelDefinition) -> Bool {
        selectedPowerups.count <= level.maxPowerupLoadoutSize
            && selectedPowerups.allSatisfy(level.availablePowerups.contains)
    }
}

