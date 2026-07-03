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
    }
}
