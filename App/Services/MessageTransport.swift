import Foundation
import AroundCore

enum TransportError: LocalizedError {
    case notSignedIn
    case underlying(String)

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            "Sign in to iCloud (Settings → your name) to chat with people around you."
        case .underlying(let message):
            message
        }
    }
}

/// Backend abstraction. Production uses `CloudKitTransport`; tests and
/// simulator-to-simulator demos use `FileTransport`. A future self-hosted
/// server becomes a third implementation without touching the UI.
@MainActor
protocol MessageTransport: AnyObject {
    /// Shown in Settings so it's obvious which backend is live.
    var kindDescription: String { get }
    /// Fired when the backend has (or may have) new messages.
    var onRemoteChange: (() -> Void)? { get set }

    func send(_ message: Message) async throws
    func fetch(zones: [String], since: Date) async throws -> [Message]
    /// Reconciles push subscriptions to exactly the given zones.
    func updateSubscriptions(zones: [String]) async throws
    /// Best-effort cleanup of this device's expired messages.
    func deleteMessages(from senderID: String, olderThan cutoff: Date) async throws
}
