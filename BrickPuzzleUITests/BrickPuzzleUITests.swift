import XCTest

final class BrickPuzzleUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testMenuLevelSelectAndGameplayFlow() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["Brick Puzzle"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["menu-level-select"].waitForExistence(timeout: 3))
        app.buttons["menu-level-select"].tap()
        XCTAssertTrue(app.otherElements["level-select"].waitForExistence(timeout: 3))
        app.buttons["level-prototype-001"].tap()
        XCTAssertTrue(app.buttons["start-attempt"].waitForExistence(timeout: 3))
        app.buttons["loadout-extraBalls"].tap()
        app.buttons["start-attempt"].tap()
        XCTAssertTrue(app.otherElements["game-board"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.otherElements["game-hud"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["game-level-select"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["powerup-extraBalls"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testSettingsAreReachable() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["menu-settings"].tap()
        XCTAssertTrue(app.otherElements["settings-screen"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.switches["Reduce Motion"].exists)
    }
}
