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

    @Test("Three star prototype requires no powerups")
    func threeStarPrototypeRequiresNoPowerups() {
        #expect(LevelDefinition.prototype.starRules.threeStarRequiresNoPowerups)
    }
}
