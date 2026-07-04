import Foundation
import UIKit
import UserNotifications
import AroundCore

/// Debug/testing backend: each message is a JSON file in a shared directory.
/// Because simulator processes share the host filesystem, two simulators
/// pointed at the same directory (env `AROUND_TRANSPORT_DIR`) can hold a
/// real conversation — and UI tests can inject "other people" by writing
/// files. Mirrors the CloudKit notification behavior by posting a local
/// notification when a message from someone else arrives while the app
/// is backgrounded.
@MainActor
final class FileTransport: MessageTransport {
    private let directory: URL
    private let localSenderID: String
    private var knownFiles: Set<String> = []
    private var timer: Timer?

    let kindDescription = "Local test directory"
    var onRemoteChange: (() -> Void)?

    init(directory: URL, localSenderID: String) {
        self.directory = directory
        self.localSenderID = localSenderID
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        knownFiles = Self.listFiles(in: directory)

        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
    }

    deinit {
        timer?.invalidate()
    }

    func send(_ message: Message) async throws {
        let data = try Self.encoder.encode(message)
        let file = directory.appendingPathComponent("\(message.id).json")
        try data.write(to: file, options: .atomic)
        knownFiles.insert(file.lastPathComponent)
    }

    func fetch(zones: [String], since: Date) async throws -> [Message] {
        allMessages().filter { zones.contains($0.geohash) && $0.sentAt > since }
    }

    func updateSubscriptions(zones: [String]) async throws {
        // Polling covers change detection in this backend.
    }

    func deleteMessages(from senderID: String, olderThan cutoff: Date) async throws {
        for message in allMessages() where message.senderID == senderID && message.sentAt < cutoff {
            let file = directory.appendingPathComponent("\(message.id).json")
            try? FileManager.default.removeItem(at: file)
            knownFiles.remove(file.lastPathComponent)
        }
    }

    // MARK: - Polling

    private func poll() {
        let current = Self.listFiles(in: directory)
        let newFiles = current.subtracting(knownFiles)
        guard !newFiles.isEmpty else {
            knownFiles = current
            return
        }
        knownFiles = current

        let incoming = newFiles.compactMap { decodeMessage(named: $0) }
        let fromOthers = incoming.filter { $0.senderID != localSenderID }
        guard !fromOthers.isEmpty else { return }

        onRemoteChange?()
        if UIApplication.shared.applicationState != .active {
            for message in fromOthers {
                postLocalNotification(for: message)
            }
        }
    }

    /// Mirrors what CloudKit's push would show, so the notification UX is
    /// testable end-to-end without an iCloud account.
    private func postLocalNotification(for message: Message) {
        let content = UNMutableNotificationContent()
        content.title = "\(message.senderName) · nearby"
        content.body = message.text
        content.sound = .default
        let request = UNNotificationRequest(identifier: message.id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - File helpers

    private func allMessages() -> [Message] {
        Self.listFiles(in: directory).compactMap { decodeMessage(named: $0) }
    }

    private func decodeMessage(named fileName: String) -> Message? {
        let file = directory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: file) else { return nil }
        return try? Self.decoder.decode(Message.self, from: data)
    }

    private static func listFiles(in directory: URL) -> Set<String> {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return Set(names.filter { $0.hasSuffix(".json") })
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
