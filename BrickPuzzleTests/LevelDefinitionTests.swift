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
