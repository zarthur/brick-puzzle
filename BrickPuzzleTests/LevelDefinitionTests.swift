import Foundation
import Testing
@testable import BrickPuzzle

@Suite("Level definitions")
struct LevelDefinitionTests {
    @Test("Prototype level defines loadout choices")
    func prototypeLevelDefinesLoadoutChoices() {
        let level = LevelDefinition.prototype

        #expect(level.maxPowerupLoadoutSize == 2)
        #expect(level.availablePowerups.count > level.maxPowerupLoadoutSize)
    }

    @Test("Loadout rejects unavailable powerup")
    func loadoutRejectsUnavailablePowerup() {
        let level = LevelDefinition.prototype
        let loadout = PowerupLoadout(selectedPowerups: [.extraBalls, .gravityShift])

        #expect(!loadout.isValid(for: level))
    }

    @Test("Loadout validation reports too many, duplicate, and unavailable choices")
    func loadoutValidationErrorsAreActionable() throws {
        let level = LevelDefinition.prototype

        #expect(throws: PowerupLoadoutError.tooMany(maximum: 2, actual: 3)) {
            try PowerupLoadout(
                selectedPowerups: [.extraBalls, .shieldBreaker, .precisionGuide]
            ).validate(for: level)
        }
        #expect(throws: PowerupLoadoutError.duplicates([.extraBalls])) {
            try PowerupLoadout(
                selectedPowerups: [.extraBalls, .extraBalls]
            ).validate(for: level)
        }
        #expect(throws: PowerupLoadoutError.unavailable([.gravityShift])) {
            try PowerupLoadout(selectedPowerups: [.gravityShift]).validate(for: level)
        }
        try PowerupLoadout(
            selectedPowerups: [.extraBalls, .precisionGuide]
        ).validate(for: level)
    }

    @Test("Three star prototype requires no powerups")
    func threeStarPrototypeRequiresNoPowerups() {
        #expect(LevelDefinition.prototype.starRules.threeStarRequiresNoPowerups)
    }
}

@Suite("Local app state")
@MainActor
struct AppStateTests {
    @Test("Progress keeps best stars and shot count while counting completions")
    func progressImprovesBestValues() {
        let storage = MemoryStorage()
        let state = AppState(storage: storage)

        state.record(result(stars: .two, shots: 4), for: "level-1")
        state.record(result(stars: .one, shots: 3), for: "level-1")
        state.record(result(stars: .three, shots: 5), for: "level-1")

        #expect(state.progress(for: "level-1") == LevelProgress(
            bestStars: 3,
            bestShotCount: 3,
            completionCount: 3
        ))
    }

    @Test("Failed attempts do not overwrite progress")
    func failedAttemptDoesNotRecord() {
        let state = AppState(storage: MemoryStorage())
        state.record(result(stars: .none, shots: 7), for: "level-1")
        #expect(state.progress(for: "level-1") == .empty)
    }

    @Test("Progress and settings reload from storage")
    func statePersists() {
        let storage = MemoryStorage()
        let first = AppState(storage: storage)
        first.record(result(stars: .two, shots: 2), for: "level-1")
        first.settings.reduceMotion = true
        first.settings.soundEnabled = false

        let restored = AppState(storage: storage)
        #expect(restored.progress(for: "level-1").bestStars == 2)
        #expect(restored.settings.reduceMotion)
        #expect(!restored.settings.soundEnabled)
    }

    private func result(stars: StarRating, shots: Int) -> AttemptResult {
        AttemptResult(
            terminalReason: stars == .none ? .shotLimitReached : .objectiveCompleted,
            stars: stars,
            shotCount: shots,
            usedPowerups: [],
            details: stars == .none ? [.failed] : [.completed]
        )
    }
}

private final class MemoryStorage: KeyValueStoring {
    private var values: [String: Any] = [:]

    func data(forKey defaultName: String) -> Data? {
        values[defaultName] as? Data
    }

    func set(_ value: Any?, forKey defaultName: String) {
        values[defaultName] = value
    }
}
