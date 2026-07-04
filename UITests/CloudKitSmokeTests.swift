import XCTest

/// Smoke test against the REAL CloudKit public database (no FileTransport).
/// Requires the `iCloud.com.sank.around` container + Message schema to
/// exist. Reads work without an iCloud login; the app polls every 4 s, so
/// a record created out-of-band (e.g. via CloudKit Console or cktool)
/// must appear in the UI.
///
/// Run:
///   TEST_RUNNER_AROUND_CLOUDKIT_SMOKE=1 xcodebuild test \
///     -project Around.xcodeproj -scheme Around \
///     -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
///     -only-testing:AroundUITests/CloudKitSmokeTests
///
/// Optional: TEST_RUNNER_AROUND_EXPECT_TEXT="..." asserts that a message
/// with that exact text (seeded server-side) shows up in the conversation.
final class CloudKitSmokeTests: XCTestCase {
    func testCloudKitFetchPath() throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["AROUND_CLOUDKIT_SMOKE"] == "1" else {
            throw XCTSkip("Driver-only test: set TEST_RUNNER_AROUND_CLOUDKIT_SMOKE=1")
        }
        continueAfterFailure = false

        // No AROUND_TRANSPORT_DIR → the app uses CloudKitTransport.
        let app = XCUIApplication()
        app.launchArguments = ["--reset-data", "--auto-onboard"]
        app.launchEnvironment = [
            "AROUND_HANDLE": "smoke-tester",
            "AROUND_FAKE_LOCATION": E2E.fakeLocation,
        ]
        app.launch()

        // Zone resolved and the CloudKit fetch loop reached the server:
        // hasLoaded flips the empty-state copy from "Checking…" to "quiet".
        XCTAssertTrue(app.staticTexts["zone \(E2E.zone)"].waitForExistence(timeout: 15))
        let expectText = environment["AROUND_EXPECT_TEXT"]
        if let expectText {
            XCTAssertTrue(
                app.staticTexts[expectText].waitForExistence(timeout: 30),
                "seeded CloudKit record did not appear in the conversation"
            )
            saveScreenshot(named: "e2e-cloudkit-fetch")
        } else {
            XCTAssertTrue(
                app.staticTexts["No one has said anything in the last 24 hours. Break the ice!"]
                    .waitForExistence(timeout: 30),
                "fetch never completed against the real CloudKit container"
            )
        }
    }
}
