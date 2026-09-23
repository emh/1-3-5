import XCTest

final class SnackFlowTests: XCTestCase {
    @MainActor
    private func selectAll(in editor: XCUIElement, app: XCUIApplication) {
        editor.tap()
        editor.press(forDuration: 1.2)
        let action = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Select All")).firstMatch
        XCTAssertTrue(action.waitForExistence(timeout: 5))
        action.tap()
    }

    @MainActor
    func testRotationActionsRequireCompleteExerciseSelection() {
        let app = launch(emptyLibrary: true)
        app.buttons["Add exercises"].tap()
        let editor = app.textViews["library-editor"]
        editor.tap()
        editor.typeText("air squats")
        XCTAssertFalse(app.buttons["mute-exercise"].exists)
        XCTAssertFalse(app.buttons["boost-exercise"].exists)
        saveScreenshot("library-cursor-only")
        editor.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 36, dy: 30)).doubleTap()
        let copy = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Copy")).firstMatch
        XCTAssertTrue(copy.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["mute-exercise"].exists)
        XCTAssertFalse(app.buttons["boost-exercise"].exists)
        saveScreenshot("library-partial-selection")
        let trailing = app.otherElements["com.apple.text.grabber.trailing"]
        XCTAssertTrue(trailing.exists)
        trailing.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1)).press(
            forDuration: 0.5,
            thenDragTo: editor.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 180, dy: 30))
        )
        XCTAssertTrue(app.buttons["mute-exercise"].isHittable)
        XCTAssertTrue(app.buttons["boost-exercise"].isHittable)
        app.buttons["mute-exercise"].tap()
        XCTAssertEqual(app.buttons["mute-exercise"].label, "Unmute")
        saveScreenshot("library-full-exercise-selection")
        editor.typeText("air squats")
        XCTAssertEqual(editor.value as? String, "air squats")
        XCTAssertFalse(app.buttons["mute-exercise"].exists)
        XCTAssertFalse(app.buttons["boost-exercise"].exists)
        saveScreenshot("library-highlight-cleared")
    }

    @MainActor
    func testSelectedLinesCanBeMutedAndBoostedTogether() {
        let app = launch(emptyLibrary: true)
        app.buttons["Add exercises"].tap()
        let editor = app.textViews["library-editor"]
        editor.tap()
        editor.typeText("pushups\nair squats\nplank")
        selectAll(in: editor, app: app)
        app.buttons["mute-exercise"].tap()
        app.buttons["boost-exercise"].tap()
        XCTAssertEqual(app.buttons["mute-exercise"].label, "Unmute")
        XCTAssertEqual(app.buttons["boost-exercise"].label, "Unboost")
        saveScreenshot("selected-library-lines")
        app.buttons["done-editing-library"].tap()
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertFalse(app.buttons["snack-size-1"].isEnabled)
        app.buttons["Manage exercises"].tap()
        selectAll(in: editor, app: app)
        app.buttons["mute-exercise"].tap()
        app.buttons["boost-exercise"].tap()
        XCTAssertEqual(app.buttons["boost-exercise"].label, "Boost 2×")
        app.buttons["done-editing-library"].tap()
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["snack-size-3"].isEnabled)
    }

    @MainActor
    func testLibraryToolbarRemainsReachableAtLargestTextSize() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-test-data", "--empty-library", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["Add exercises"].waitForExistence(timeout: 5))
        app.buttons["Add exercises"].tap()
        let editor = app.textViews["library-editor"]
        editor.tap()
        editor.typeText("kb clean & presses\nplank")
        XCTAssertFalse(app.buttons["mute-exercise"].exists)
        editor.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 90, dy: 190)).doubleTap()
        XCTAssertTrue(app.buttons["mute-exercise"].isHittable)
        XCTAssertTrue(app.buttons["boost-exercise"].isHittable)
        app.buttons["mute-exercise"].tap()
        app.buttons["boost-exercise"].tap()
        XCTAssertTrue(app.buttons["done-editing-library"].isHittable)
        saveScreenshot("large-text-library-toolbar")
        app.buttons["done-editing-library"].tap()
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["snack-size-1"].isEnabled)
    }

    @MainActor
    func testMuteBoostAndRenamePersistAndControlRotation() {
        let app = launch(emptyLibrary: true)
        app.buttons["Add exercises"].tap()
        let editor = app.textViews["library-editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("pushups")
        selectAll(in: editor, app: app)
        let mute = app.buttons["mute-exercise"]
        let boost = app.buttons["boost-exercise"]
        XCTAssertTrue(mute.waitForExistence(timeout: 5))
        mute.tap()
        boost.tap()
        XCTAssertEqual(mute.label, "Unmute")
        XCTAssertEqual(boost.label, "Unboost")
        XCTAssertEqual(mute.value as? String, "Muted")
        XCTAssertEqual(boost.value as? String, "Double weight")
        editor.typeText("pushups on knees")
        XCTAssertEqual(editor.value as? String, "pushups on knees")
        XCTAssertFalse(mute.exists)
        selectAll(in: editor, app: app)
        XCTAssertEqual(mute.label, "Unmute")
        saveScreenshot("muted-and-boosted-library")
        app.buttons["done-editing-library"].tap()
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertFalse(app.buttons["snack-size-1"].isEnabled)
        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["Manage exercises"].waitForExistence(timeout: 5))
        app.buttons["Manage exercises"].tap()
        selectAll(in: editor, app: app)
        XCTAssertTrue(mute.waitForExistence(timeout: 5))
        XCTAssertEqual(mute.label, "Unmute")
        XCTAssertEqual(boost.label, "Unboost")
        mute.tap()
        XCTAssertEqual(mute.label, "Mute")
        XCTAssertEqual(boost.label, "Unboost")
        saveScreenshot("boosted-library")
        app.buttons["done-editing-library"].tap()
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["snack-size-1"].isEnabled)
        app.buttons["snack-size-1"].tap()
        XCTAssertTrue(app.buttons["reroll-0"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["reroll-0"].label, "Reroll pushups on knees")
    }

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    private func launch(emptyLibrary: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-test-data"] + (emptyLibrary ? ["--empty-library"] : [])
        app.launch()
        XCTAssertTrue(app.buttons["snack-size-3"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor
    private func waitForLabel(_ label: String, on element: XCUIElement) {
        let predicate = NSPredicate(format: "label == %@", label)
        expectation(for: predicate, evaluatedWith: element)
        waitForExpectations(timeout: 5)
    }

    @MainActor
    private func saveScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testPreviewPauseSkipCompleteAndRelaunch() {
        let app = launch()
        app.buttons["snack-size-3"].tap()
        XCTAssertTrue(app.buttons["start-snack"].waitForExistence(timeout: 5))
        let first = app.buttons["reroll-0"].label
        let middle = app.buttons["reroll-1"].label
        let last = app.buttons["reroll-2"].label
        app.buttons["reroll-1"].tap()
        XCTAssertNotEqual(app.buttons["reroll-1"].label, middle)
        XCTAssertEqual(app.buttons["reroll-0"].label, first)
        XCTAssertEqual(app.buttons["reroll-2"].label, last)
        saveScreenshot("preview-three-exercises")
        app.buttons["start-snack"].tap()
        XCTAssertTrue(app.buttons["pause-resume"].waitForExistence(timeout: 5))
        app.buttons["pause-resume"].tap()
        waitForLabel("Resume", on: app.buttons["pause-resume"])
        XCTAssertEqual(app.staticTexts["countdown"].label, "Paused")
        saveScreenshot("paused")
        app.buttons["skip"].tap()
        waitForLabel("Exercise 2 of 3", on: app.staticTexts["exercise-position"])
        XCTAssertEqual(app.buttons["pause-resume"].label, "Resume")
        app.buttons["pause-resume"].tap()
        app.buttons["skip"].tap()
        waitForLabel("Exercise 3 of 3", on: app.staticTexts["exercise-position"])
        app.buttons["skip"].tap()
        let records = app.descendants(matching: .any).matching(identifier: "snack-record")
        XCTAssertTrue(records.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(records.count, 1)
        saveScreenshot("completed-snack")
        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(records.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(records.count, 1)
    }

    @MainActor
    func testCancellingPreviewAndActiveSnackDoesNotLog() {
        let app = launch()
        app.buttons["snack-size-5"].tap()
        XCTAssertTrue(app.buttons["close-preview"].waitForExistence(timeout: 5))
        app.buttons["close-preview"].tap()
        XCTAssertTrue(app.staticTexts["NO SNACKS YET"].waitForExistence(timeout: 5))
        app.buttons["snack-size-3"].tap()
        app.buttons["start-snack"].tap()
        XCTAssertTrue(app.buttons["cancel-snack"].waitForExistence(timeout: 5))
        app.buttons["cancel-snack"].tap()
        app.alerts.buttons["Keep Going"].tap()
        waitForLabel("Pause", on: app.buttons["pause-resume"])
        app.buttons["cancel-snack"].tap()
        app.alerts.buttons["End Snack"].tap()
        XCTAssertTrue(app.staticTexts["NO SNACKS YET"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "snack-record").count, 0)
    }

    @MainActor
    func testEmptyLibraryEditingAutosavesAndDisablesLargerSizes() {
        let app = launch(emptyLibrary: true)
        XCTAssertFalse(app.buttons["snack-size-1"].isEnabled)
        app.buttons["Add exercises"].tap()
        let editor = app.textViews["library-editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("pushups\ndead hang")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["snack-size-1"].isEnabled)
        XCTAssertFalse(app.buttons["snack-size-3"].isEnabled)
        XCTAssertFalse(app.buttons["snack-size-5"].isEnabled)
        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["snack-size-1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["snack-size-1"].isEnabled)
        XCTAssertFalse(app.buttons["snack-size-3"].isEnabled)
        app.buttons["settings"].tap()
        app.buttons["exercise-library"].tap()
        XCTAssertEqual(editor.value as? String, "pushups\ndead hang")
    }

    @MainActor
    func testPausedSnackSurvivesProcessTermination() {
        let app = launch()
        app.buttons["snack-size-1"].tap()
        app.buttons["start-snack"].tap()
        XCTAssertTrue(app.buttons["pause-resume"].waitForExistence(timeout: 5))
        app.buttons["pause-resume"].tap()
        waitForLabel("Resume", on: app.buttons["pause-resume"])
        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["pause-resume"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["pause-resume"].label, "Resume")
        XCTAssertEqual(app.staticTexts["countdown"].label, "Paused")
        app.buttons["skip"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "snack-record").firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    func testLargestTextKeepsPreviewAndTimerControlsReachable() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-test-data", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["snack-size-5"].waitForExistence(timeout: 5))
        app.buttons["snack-size-5"].tap()
        XCTAssertTrue(app.buttons["start-snack"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["start-snack"].isHittable)
        saveScreenshot("large-text-preview")
        app.buttons["start-snack"].tap()
        XCTAssertTrue(app.buttons["pause-resume"].waitForExistence(timeout: 5))
        for _ in 0..<4 where !app.buttons["pause-resume"].isHittable { app.scrollViews["active-scroll"].swipeUp() }
        XCTAssertTrue(app.buttons["pause-resume"].isHittable)
        XCTAssertTrue(app.buttons["skip"].isHittable)
        app.buttons["pause-resume"].tap()
        waitForLabel("Resume", on: app.buttons["pause-resume"])
        saveScreenshot("large-text-paused")
    }

    @MainActor
    func testRunningTimerKeepsCountingWhileBackgrounded() {
        let app = launch()
        app.buttons["snack-size-3"].tap()
        app.buttons["start-snack"].tap()
        let countdown = app.staticTexts["countdown"]
        XCTAssertTrue(countdown.waitForExistence(timeout: 5))
        let before = Int(countdown.label.split(separator: " ")[0])!
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 3)
        app.activate()
        XCTAssertTrue(countdown.waitForExistence(timeout: 5))
        let after = Int(countdown.label.split(separator: " ")[0])!
        XCTAssertLessThanOrEqual(after, before - 3)
        XCTAssertEqual(app.buttons["pause-resume"].label, "Pause")
        saveScreenshot("running-after-background")
    }
}
