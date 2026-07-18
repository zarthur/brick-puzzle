import XCTest

final class BrickPuzzleUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAppLaunchesToPrototypeBoard() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["Brick Puzzle"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["start-attempt"].waitForExistence(timeout: 3))
        app.buttons["loadout-extraBalls"].tap()
        app.buttons["start-attempt"].tap()
        XCTAssertTrue(app.otherElements["game-board"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["powerup-extraBalls"].waitForExistence(timeout: 3))
    }
}
