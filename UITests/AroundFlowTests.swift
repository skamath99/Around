import XCTest

/// End-to-end flows on a single simulator, using the file transport.
/// Run: xcodebuild test -project Around.xcodeproj -scheme Around \
///        -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
///        -only-testing:AroundUITests/AroundFlowTests
final class AroundFlowTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testOnboardingSendAndReceive() throws {
        let dir = E2E.freshTransportDir("flow")
        let app = XCUIApplication.around(transportDir: dir, handle: "amber-fox-42")
        app.launch()

        // Onboarding
        XCTAssertTrue(app.staticTexts["Around"].waitForExistence(timeout: 5))
        let handleField = app.textFields["handleField"]
        XCTAssertTrue(handleField.exists)
        XCTAssertEqual(handleField.value as? String, "amber-fox-42", "handle should be prefilled from env")
        app.buttons["continueButton"].tap()
        app.allowNotificationsIfAsked()

        // Empty room for our zone
        XCTAssertTrue(app.staticTexts["It's quiet around here"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["zone \(E2E.zone)"].waitForExistence(timeout: 5))

        // Send a message; it should appear as "you"
        app.sendMessage("First post from the flow test")
        XCTAssertTrue(app.staticTexts["First post from the flow test"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["you"].exists)

        // Another device speaks: inject a file and expect it to appear live
        try E2E.inject(text: "Hello neighbor!", into: dir, senderName: "hazel-otter-7")
        XCTAssertTrue(app.staticTexts["Hello neighbor!"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["hazel-otter-7"].exists)

        // Relaunch: onboarding must be skipped, messages still visible
        app.terminate()
        let relaunched = XCUIApplication.around(transportDir: dir, handle: "amber-fox-42", reset: false)
        relaunched.launch()
        XCTAssertTrue(relaunched.staticTexts["Hello neighbor!"].waitForExistence(timeout: 10))
        XCTAssertFalse(relaunched.buttons["continueButton"].exists, "should not re-onboard")
    }

    func testExpiredAndForeignZoneMessagesAreHidden() throws {
        let dir = E2E.freshTransportDir("ttl")
        try E2E.inject(text: "Ancient history", into: dir, sentAt: Date().addingTimeInterval(-25 * 3600))
        try E2E.inject(text: "Message from another city", into: dir, zone: "u4pruyd")
        try E2E.inject(text: "Fresh and local", into: dir, sentAt: Date().addingTimeInterval(-3600))

        let app = XCUIApplication.around(transportDir: dir, autoOnboard: true)
        app.launch()

        XCTAssertTrue(app.staticTexts["Fresh and local"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Ancient history"].exists, "24h-old message must be hidden")
        XCTAssertFalse(app.staticTexts["Message from another city"].exists, "other zone must be hidden")
    }

    func testIncomingMessageWhileBackgroundedShowsNotification() throws {
        let dir = E2E.freshTransportDir("notif")
        let app = XCUIApplication.around(transportDir: dir, handle: "amber-fox-42")
        app.launch()
        app.buttons["continueButton"].tap()
        app.allowNotificationsIfAsked()
        XCTAssertTrue(app.staticTexts["It's quiet around here"].waitForExistence(timeout: 10))

        // Background the app, then a neighbor sends a message.
        XCUIDevice.shared.press(.home)
        sleep(2)
        try E2E.inject(text: "Anyone around for coffee?", into: dir, senderName: "lunar-crane-3")

        // The notification banner should appear on springboard.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let banner = springboard.staticTexts["Anyone around for coffee?"]
        XCTAssertTrue(banner.waitForExistence(timeout: 15), "expected a notification banner")
        saveScreenshot(named: "e2e-notification-banner")

        // Tapping it returns to the conversation with the message visible.
        banner.tap()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(app.staticTexts["Anyone around for coffee?"].waitForExistence(timeout: 10))
    }
}
