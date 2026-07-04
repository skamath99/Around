import XCTest

/// Generates the marketing/README screenshots into screenshots/.
/// Run: xcodebuild test -project Around.xcodeproj -scheme Around \
///        -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
///        -only-testing:AroundUITests/ScreenshotTourTests
final class ScreenshotTourTests: XCTestCase {
    func testTour() throws {
        continueAfterFailure = false
        let dir = E2E.freshTransportDir("tour")

        // Seed a lively-looking conversation from "neighbors".
        try E2E.inject(
            text: "Farmers market on 24th is popping right now 🍑",
            into: dir, senderName: "lunar-crane-3",
            sentAt: Date().addingTimeInterval(-52 * 60)
        )
        try E2E.inject(
            text: "Anyone else hear that music from the park?",
            into: dir, senderName: "hazel-otter-7",
            sentAt: Date().addingTimeInterval(-14 * 60)
        )
        try E2E.inject(
            text: "Yeah! Free show at the bandshell until 6",
            into: dir, senderName: "plucky-wren-88",
            sentAt: Date().addingTimeInterval(-11 * 60)
        )

        let app = XCUIApplication.around(transportDir: dir, handle: "amber-fox-42")
        app.launch()

        XCTAssertTrue(app.buttons["continueButton"].waitForExistence(timeout: 5))
        saveScreenshot(named: "01-onboarding")

        app.buttons["continueButton"].tap()
        app.allowNotificationsIfAsked()

        XCTAssertTrue(app.staticTexts["Anyone else hear that music from the park?"].waitForExistence(timeout: 10))
        app.sendMessage("On my way with a picnic blanket 🧺")
        XCTAssertTrue(app.staticTexts["On my way with a picnic blanket 🧺"].waitForExistence(timeout: 5))
        saveScreenshot(named: "02-chat")

        app.buttons["settingsButton"].tap()
        XCTAssertTrue(app.staticTexts["How Around works"].waitForExistence(timeout: 5))
        saveScreenshot(named: "03-settings")
        app.buttons["settingsDoneButton"].tap()
    }
}
