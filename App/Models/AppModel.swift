import Foundation
import UIKit
import UserNotifications
import AroundCore

/// App-wide state: local identity, onboarding, and the active transport.
///
/// Test conveniences (used by UI tests and the two-simulator demo):
/// - `--reset-data`            wipe UserDefaults on launch
/// - `--auto-onboard`          skip the onboarding screen
/// - `AROUND_TRANSPORT_DIR`    use FileTransport rooted at this directory
/// - `AROUND_HANDLE`           preset the display handle
/// - `AROUND_FAKE_LOCATION`    pin location to "lat,lon" (see LocationService)
@MainActor
final class AppModel: ObservableObject {
    @Published var onboarded: Bool {
        didSet { defaults.set(onboarded, forKey: Keys.onboarded) }
    }
    @Published var handle: String {
        didSet { defaults.set(handle, forKey: Keys.handle) }
    }

    let senderID: String
    let transport: MessageTransport
    let location = LocationService()
    private(set) lazy var chat = ChatViewModel(transport: transport, location: location)

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let onboarded = "onboarded"
        static let handle = "handle"
        static let senderID = "senderID"
    }

    init() {
        let environment = ProcessInfo.processInfo.environment
        let arguments = ProcessInfo.processInfo.arguments

        if arguments.contains("--reset-data"), let bundleID = Bundle.main.bundleIdentifier {
            defaults.removePersistentDomain(forName: bundleID)
        }

        if let existing = defaults.string(forKey: Keys.senderID) {
            senderID = existing
        } else {
            senderID = UUID().uuidString
            defaults.set(senderID, forKey: Keys.senderID)
        }

        let handle = environment["AROUND_HANDLE"]
            ?? defaults.string(forKey: Keys.handle)
            ?? HandleGenerator.random()
        self.handle = handle
        defaults.set(handle, forKey: Keys.handle)

        onboarded = defaults.bool(forKey: Keys.onboarded) || arguments.contains("--auto-onboard")

        if let path = environment["AROUND_TRANSPORT_DIR"] {
            transport = FileTransport(
                directory: URL(fileURLWithPath: path, isDirectory: true),
                localSenderID: senderID
            )
        } else {
            transport = CloudKitTransport()
        }
    }

    func completeOnboarding(handle: String) {
        let trimmed = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        self.handle = trimmed.isEmpty ? HandleGenerator.random() : trimmed
        onboarded = true
        requestNotificationPermission()
    }

    func requestNotificationPermission() {
        Task {
            _ = try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
}
