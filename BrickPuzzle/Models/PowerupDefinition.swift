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

    static let empty = PowerupLoadout(selectedPowerups: [])

    func validate(for level: LevelDefinition) throws {
        if selectedPowerups.count > level.maxPowerupLoadoutSize {
            throw PowerupLoadoutError.tooMany(
                maximum: level.maxPowerupLoadoutSize,
                actual: selectedPowerups.count
            )
        }
        let duplicateIDs = Dictionary(grouping: selectedPowerups, by: \.self)
            .filter { $0.value.count > 1 }
            .map(\.key)
            .sorted { $0.rawValue < $1.rawValue }
        if !duplicateIDs.isEmpty {
            throw PowerupLoadoutError.duplicates(duplicateIDs)
        }
        let unavailable = selectedPowerups
            .filter { !level.availablePowerups.contains($0) }
            .sorted { $0.rawValue < $1.rawValue }
        if !unavailable.isEmpty {
            throw PowerupLoadoutError.unavailable(unavailable)
        }
    }

    func isValid(for level: LevelDefinition) -> Bool {
        (try? validate(for: level)) != nil
    }
}

enum PowerupLoadoutError: Error, Equatable {
    case tooMany(maximum: Int, actual: Int)
    case duplicates([PowerupDefinition])
    case unavailable([PowerupDefinition])
}
