import XCTest

/// One half of a two-simulator conversation. The driver script
/// (scripts/two_sim_e2e.sh) runs this test concurrently on two different
/// simulators — one with TEST_RUNNER_AROUND_E2E_ROLE=A, one with =B —
/// sharing a transport directory on the host filesystem. A sends, B
/// replies, both assert they saw the other side.
final class TwoSimulatorConversationTests: XCTestCase {
    func testConversationRole() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let role = environment["AROUND_E2E_ROLE"] else {
            throw XCTSkip("Driver-only test: set TEST_RUNNER_AROUND_E2E_ROLE=A or B")
        }
        guard let dir = environment["AROUND_E2E_DIR"] else {
            throw XCTSkip("Driver-only test: set TEST_RUNNER_AROUND_E2E_DIR")
        }
        continueAfterFailure = false

        let handle = role == "A" ? "alice-fox-1" : "bob-otter-2"
        let app = XCUIApplication.around(transportDir: dir, handle: handle, autoOnboard: true)
        app.launch()
        XCTAssertTrue(app.staticTexts["zone \(E2E.zone)"].waitForExistence(timeout: 15))

        let ping = "Ping! Anyone around?"
        let pong = "Pong — loud and clear from next door"

        if role == "A" {
            app.sendMessage(ping)
            XCTAssertTrue(app.staticTexts[ping].waitForExistence(timeout: 10))
            saveScreenshot(named: "e2e-two-sim-A-sent")
            // Wait for B's reply to arrive over the shared transport.
            XCTAssertTrue(
                app.staticTexts[pong].waitForExistence(timeout: 90),
                "A never received B's reply"
            )
            XCTAssertTrue(app.staticTexts["bob-otter-2"].exists)
            saveScreenshot(named: "e2e-two-sim-A-final")
        } else {
            XCTAssertTrue(
                app.staticTexts[ping].waitForExistence(timeout: 90),
                "B never received A's message"
            )
            XCTAssertTrue(app.staticTexts["alice-fox-1"].exists)
            app.sendMessage(pong)
            XCTAssertTrue(app.staticTexts[pong].waitForExistence(timeout: 10))
            saveScreenshot(named: "e2e-two-sim-B-final")
        }
    }
}
