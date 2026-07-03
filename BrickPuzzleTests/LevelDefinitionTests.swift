import XCTest
@testable import BrickPuzzle

final class LevelDefinitionTests: XCTestCase {
    func testPrototypeLevelDefinesLoadoutChoices() {
        let level = LevelDefinition.prototype

        XCTAssertEqual(level.maxPowerupLoadoutSize, 2)
        XCTAssertGreaterThan(level.availablePowerups.count, level.maxPowerupLoadoutSize)
    }

    func testLoadoutRejectsUnavailablePowerup() {
        let level = LevelDefinition.prototype
        let loadout = PowerupLoadout(selectedPowerups: [.extraBalls, .gravityShift])

        XCTAssertFalse(loadout.isValid(for: level))
    }

    func testThreeStarPrototypeRequiresNoPowerups() {
        XCTAssertTrue(LevelDefinition.prototype.starRules.threeStarRequiresNoPowerups)
    }
}

