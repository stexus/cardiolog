import XCTest

final class CardioLogUITests: XCTestCase {
    @MainActor func testTimerLibraryRememberedSelectionAndPinnedStart() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-preview-preferences"]
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        app.launch()
        let start = app.buttons["start-workout"]
        XCTAssertTrue(start.waitForExistence(timeout: 15))
        XCTAssertTrue(start.isHittable)
        let back = app.navigationBars.buttons["Timers"].firstMatch
        XCTAssertGreaterThanOrEqual(back.frame.minY, app.staticTexts["sample-banner"].frame.maxY)
        let initialY = start.frame.minY
        app.scrollViews.firstMatch.swipeUp()
        XCTAssertEqual(start.frame.minY, initialY, accuracy: 1)
        XCTAssertTrue(start.isHittable)
        app.navigationBars.buttons["Timers"].firstMatch.tap()
        XCTAssertTrue(app.buttons["template-steady"].waitForExistence(timeout: 5))
        app.buttons["template-steady"].tap()
        XCTAssertTrue(app.navigationBars["Steady ride"].waitForExistence(timeout: 5))
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.navigationBars["Steady ride"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Timers"].tap()
        XCTAssertTrue(app.buttons["template-steady"].waitForExistence(timeout: 5))
        let library = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        library.name = "Native timer library"; library.lifetime = .keepAlways; add(library)
        app.buttons["template-norwegian"].tap()
        app.tabBars.buttons["History"].tap()
        app.tabBars.buttons["Timers"].tap()
        XCTAssertTrue(app.buttons["template-norwegian"].waitForExistence(timeout: 5))
        app.buttons["template-norwegian"].tap()
        XCTAssertTrue(start.isHittable)
        let setup = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        setup.name = "Native timer setup"; setup.lifetime = .keepAlways; add(setup)
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertTrue(start.isHittable)
        app.scrollViews.firstMatch.swipeUp()
        XCTAssertTrue(start.isHittable)
        XCUIDevice.shared.orientation = .portrait
        app.tabBars.buttons["Timers"].tap()
        app.buttons["new-template"].tap()
        XCTAssertTrue(app.textFields["Name"].waitForExistence(timeout: 5))
        app.textFields["Name"].tap()
        app.textFields["Name"].typeText(" saved")
        app.buttons["Save"].tap()
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.navigationBars["My workout saved"].waitForExistence(timeout: 15))
    }

    @MainActor func testSaveSampleSurvivesRelaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-preview-storage", "--preview-state", "paused"]
        app.launch()
        XCTAssertTrue(app.buttons["finish-workout"].waitForExistence(timeout: 15))
        app.buttons["finish-workout"].tap()
        app.buttons["confirm-finish"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Copy Workout"].waitForExistence(timeout: 10))
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["13:00 · 1 work intervals"].waitForExistence(timeout: 5))
        app.terminate()
        app.launchArguments = []
        app.launch()
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["13:00 · 1 work intervals"].waitForExistence(timeout: 10))
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "Sample history after relaunch"; attachment.lifetime = .keepAlways
        add(attachment)
    }
    @MainActor func testLandscapeDarkAndCompletedScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--preview-state", "paused", "--preview-appearance", "dark"]
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        app.launch()
        XCTAssertTrue(app.buttons["pause-resume"].waitForExistence(timeout: 15))
        XCUIDevice.shared.orientation = .landscapeLeft
        let rotated = NSPredicate { _, _ in app.windows.firstMatch.frame.width > app.windows.firstMatch.frame.height }
        expectation(for: rotated, evaluatedWith: app)
        waitForExpectations(timeout: 10)
        XCTAssertTrue(app.buttons["pause-resume"].isHittable)
        XCTAssertTrue(app.buttons["finish-workout"].isHittable)
        let landscape = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        landscape.name = "Native paused dark landscape"; landscape.lifetime = .keepAlways; add(landscape)
        app.terminate()
        XCUIDevice.shared.orientation = .portrait
        app.launchArguments = ["--preview-state", "completed", "--preview-appearance", "light"]
        app.launch()
        XCTAssertTrue(app.staticTexts["COMPLETED · SAMPLE"].waitForExistence(timeout: 15))
        let detail = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        detail.name = "Native completed light portrait"; detail.lifetime = .keepAlways; add(detail)
    }
    @MainActor func testNoHRStillAllowsPauseAndResume() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--preview-state", "no-hr"]
        app.launch()
        XCTAssertTrue(app.buttons["pause-resume"].waitForExistence(timeout: 15))
        app.buttons["pause-resume"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "PAUSED")).firstMatch.exists)
        let before = app.staticTexts["countdown"].label
        sleep(2)
        XCTAssertEqual(before, app.staticTexts["countdown"].label)
        app.buttons["pause-resume"].tap()
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "PAUSED")).firstMatch.exists)
    }
}
