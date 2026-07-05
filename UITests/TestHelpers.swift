import XCTest
import AroundCore

/// Simulator processes share the host filesystem, so tests (and a second
/// simulator) can exchange messages with the app through a plain directory.
enum E2E {
    static let fakeLocation = "37.7749,-122.4194" // SF, zone 9q8yyk8
    static let projectScreenshotsDir = "/Users/sank/Documents/Projects/Around/screenshots"

    static var zone: String {
        Geohash.encode(latitude: 37.7749, longitude: -122.4194)
    }

    static func freshTransportDir(_ label: String) -> String {
        let dir = "/tmp/around-uitests/\(label)-\(UUID().uuidString.prefix(8))"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Drops a message file into the transport directory, as if another
    /// nearby device had sent it.
    static func inject(
        text: String,
        into dir: String,
        senderID: String = "other-device",
        senderName: String = "hazel-otter-7",
        zone: String? = nil,
        sentAt: Date = .now
    ) throws {
        let message = Message(
            text: text,
            senderID: senderID,
            senderName: senderName,
            geohash: zone ?? self.zone,
            sentAt: sentAt
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(message)
        try data.write(to: URL(fileURLWithPath: "\(dir)/\(message.id).json"), options: .atomic)
    }
}

extension XCUIApplication {
    static func around(
        transportDir: String,
        handle: String = "test-otter-1",
        reset: Bool = true,
        autoOnboard: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments: [String] = []
        if reset { arguments.append("--reset-data") }
        if autoOnboard { arguments.append("--auto-onboard") }
        app.launchArguments = arguments
        app.launchEnvironment = [
            "AROUND_TRANSPORT_DIR": transportDir,
            "AROUND_HANDLE": handle,
            "AROUND_FAKE_LOCATION": E2E.fakeLocation,
        ]
        return app
    }

    /// The compose TextField uses `axis: .vertical`, which XCUITest exposes
    /// as a text view.
    var composeField: XCUIElement {
        textViews["composeField"].exists ? textViews["composeField"] : textFields["composeField"]
    }

    func sendMessage(_ text: String) {
        composeField.tap()
        composeField.typeText(text)
        buttons["sendButton"].tap()
    }

    /// Accepts the notification-permission alert if it appears.
    func allowNotificationsIfAsked() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow"]
        if allow.waitForExistence(timeout: 5) {
            allow.tap()
        }
    }
}

extension XCTestCase {
    func saveScreenshot(named name: String) {
        let dir = ProcessInfo.processInfo.environment["AROUND_SCREENSHOT_DIR"]
            ?? E2E.projectScreenshotsDir
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
    }
}
