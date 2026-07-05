import XCTest
import AroundCore

/// E2E coverage for the five UX issues (keyboard dismissal, settings clarity,
/// zone-code copy, message copy, bubble grouping), with edge cases: grouping
/// window boundaries, interleaved senders, cross-zone groups, live messages
/// joining a group, and multiline/emoji copy fidelity.
/// NOTE: tests are lettered to force execution order. Cross-process
/// pasteboard access (the runner reading UIPasteboard) can wedge the
/// simulator's pasteboardd; once wedged, any text-field *focus* in the app
/// blocks forever on UIKit's pasteboard cache queue. Keyboard/typing tests
/// therefore run before anything that reads the pasteboard.
final class IssueFixesTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: - #1 keyboard dismissal

    func testA_TapOutsideCollapsesKeyboard() throws {
        let dir = E2E.freshTransportDir("keyboard")
        let app = XCUIApplication.around(transportDir: dir, autoOnboard: true)
        app.launch()

        // Empty state: tapping the placeholder area drops the keyboard.
        XCTAssertTrue(app.staticTexts["It's quiet around here"].waitForExistence(timeout: 10))
        app.composeField.tap()
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 5), "keyboard should appear")
        app.staticTexts["It's quiet around here"].tap()
        waitForKeyboardDismissal(app)

        // Populated list: the send button must not be swallowed by the
        // dismiss gesture, and tapping the list drops the keyboard.
        app.sendMessage("keyboard test message")
        XCTAssertTrue(app.staticTexts["keyboard test message"].waitForExistence(timeout: 5))
        app.composeField.tap()
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 5))
        app.scrollViews["messageList"].tap()
        waitForKeyboardDismissal(app)

        // Long-press context menu still works while the keyboard is up.
        app.composeField.tap()
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 5))
        app.staticTexts["keyboard test message"].press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["Copy"].waitForExistence(timeout: 5), "context menu should open despite keyboard")
    }

    // MARK: - #4 copy message text (multiline + emoji fidelity)

    func testD_CopyMessageTextPreservesContent() throws {
        let text = "Multi-line ☕️ message\nsecond line 🌊 done"
        let dir = E2E.freshTransportDir("copy-msg")
        try E2E.inject(text: text, into: dir)

        let app = XCUIApplication.around(transportDir: dir, autoOnboard: true)
        app.launch()

        let bubble = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "Multi-line")
        ).firstMatch
        XCTAssertTrue(bubble.waitForExistence(timeout: 10))
        bubble.press(forDuration: 1.2)

        let copy = app.buttons["Copy"]
        XCTAssertTrue(copy.waitForExistence(timeout: 5), "long press should open a Copy menu")
        copy.tap()

        XCTAssertEqual(readPasteboard(), text, "copied text must match byte-exact incl. newline and emoji")
    }

    // MARK: - #2 + #3 settings clarity and zone-code copy

    func testC_SettingsEditabilityAndZoneCopy() throws {
        let dir = E2E.freshTransportDir("settings")
        let app = XCUIApplication.around(transportDir: dir, autoOnboard: true)
        app.launch()

        XCTAssertTrue(app.staticTexts["zone \(E2E.zone)"].waitForExistence(timeout: 10))
        app.buttons["settingsButton"].tap()

        // #2: the handle is visibly the only editable setting.
        let handleField = app.textFields["settingsHandleField"]
        XCTAssertTrue(handleField.waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.staticTexts["The only setting you can change — how your name appears to people nearby."].exists,
            "handle section should explain it is the only editable field"
        )
        XCTAssertTrue(app.staticTexts["About Around"].exists, "read-only info should sit under an informational header")
        handleField.tap()
        handleField.typeText("x")
        XCTAssertTrue((handleField.value as? String)?.hasSuffix("x") == true, "handle must stay editable")

        // #3: copy the zone code and verify the pasteboard.
        saveScreenshot(named: "e2e-settings-editability")
        let copyButton = app.buttons["copyZoneButton"]
        XCTAssertTrue(copyButton.waitForExistence(timeout: 5))
        copyButton.tap()
        XCTAssertEqual(readPasteboard(), E2E.zone, "pasteboard should hold exactly the zone code")
    }

    // MARK: - #5 grouping: boundaries, interleaving, cross-zone, live updates

    func testB_ConsecutiveMessagesGroupWithEdgeCases() throws {
        let dir = E2E.freshTransportDir("grouping")
        let northZone = try XCTUnwrap(Geohash.adjacent(E2E.zone, .north))
        let now = Date()

        // alice: gap of exactly 120 s groups (inclusive), 121 s starts a new group.
        try E2E.inject(text: "alice one", into: dir, senderID: "alice-id", senderName: "alice-fox-1", sentAt: now.addingTimeInterval(-400))
        try E2E.inject(text: "alice two", into: dir, senderID: "alice-id", senderName: "alice-fox-1", sentAt: now.addingTimeInterval(-280))
        try E2E.inject(text: "alice three", into: dir, senderID: "alice-id", senderName: "alice-fox-1", sentAt: now.addingTimeInterval(-159))
        // interleaved senders never group across each other (A, B, A).
        try E2E.inject(text: "bob one", into: dir, senderID: "bob-id", senderName: "bob-owl-2", sentAt: now.addingTimeInterval(-100))
        try E2E.inject(text: "alice four", into: dir, senderID: "alice-id", senderName: "alice-fox-1", sentAt: now.addingTimeInterval(-90))
        try E2E.inject(text: "bob two", into: dir, senderID: "bob-id", senderName: "bob-owl-2", sentAt: now.addingTimeInterval(-80))
        // carol: same sender straddling two zone cells still groups visually.
        try E2E.inject(text: "carol here", into: dir, senderID: "carol-id", senderName: "carol-elk-3", sentAt: now.addingTimeInterval(-70))
        try E2E.inject(text: "carol next door", into: dir, senderID: "carol-id", senderName: "carol-elk-3", zone: northZone, sentAt: now.addingTimeInterval(-60))

        let app = XCUIApplication.around(transportDir: dir, autoOnboard: true)
        app.launch()

        XCTAssertTrue(app.staticTexts["carol next door"].waitForExistence(timeout: 10))
        XCTAssertEqual(senderHeaderCount(app, "alice-fox-1"), 3, "120 s gap groups, 121 s and interleaved bob do not")
        XCTAssertEqual(senderHeaderCount(app, "bob-owl-2"), 2, "interleaved messages never group")
        XCTAssertEqual(senderHeaderCount(app, "carol-elk-3"), 1, "same sender groups across neighboring zones")

        // Own messages sent in quick succession collapse under one "you".
        app.sendMessage("mine one")
        app.sendMessage("mine two")
        XCTAssertTrue(app.staticTexts["mine two"].waitForExistence(timeout: 5))
        XCTAssertEqual(senderHeaderCount(app, "you"), 1, "own rapid messages should share one header")

        // A live incoming message joins an existing group: still one header.
        try E2E.inject(text: "dave first", into: dir, senderID: "dave-id", senderName: "dave-hare-4")
        XCTAssertTrue(app.staticTexts["dave first"].waitForExistence(timeout: 10))
        try E2E.inject(text: "dave second", into: dir, senderID: "dave-id", senderName: "dave-hare-4")
        XCTAssertTrue(app.staticTexts["dave second"].waitForExistence(timeout: 10))
        XCTAssertEqual(senderHeaderCount(app, "dave-hare-4"), 1, "live message should join the open group")

        // Footers ("fades …") appear once per group: alice(3) + bob(2) +
        // carol(1) + you(1) + dave(1) = 8 groups.
        XCTAssertEqual(
            app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'fades'")).count, 8,
            "exactly one fades footer per visual group"
        )
        saveScreenshot(named: "e2e-grouped-bubbles")
    }

    // MARK: - helpers

    private func waitForKeyboardDismissal(_ app: XCUIApplication) {
        let gone = expectation(for: NSPredicate(format: "count == 0"), evaluatedWith: app.keyboards)
        wait(for: [gone], timeout: 5)
    }

    private func senderHeaderCount(_ app: XCUIApplication, _ name: String) -> Int {
        app.staticTexts.matching(NSPredicate(format: "label == %@", name)).count
    }

    /// Reads the simulator-wide general pasteboard, dismissing the paste
    /// permission alert if iOS raises one for the test runner.
    private func readPasteboard() -> String? {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.alerts.buttons["Allow Paste"]
        if allow.waitForExistence(timeout: 2) { allow.tap() }
        return UIPasteboard.general.string
    }
}
