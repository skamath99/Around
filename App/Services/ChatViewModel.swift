import Combine
import Foundation
import AroundCore

@MainActor
final class ChatViewModel: ObservableObject {
    /// Messages currently visible (zone-filtered, unexpired, sorted).
    @Published private(set) var messages: [Message] = []
    /// The device's own geohash cell, once located.
    @Published private(set) var zone: String?
    /// Non-nil after a failed send; drives an alert.
    @Published var sendError: String?
    /// True once at least one fetch has completed for the current zone.
    @Published private(set) var hasLoaded = false

    let locationService: LocationService
    private let transport: MessageTransport
    private var zones: [String] = []
    private var allMessages: [Message] = []
    private var refreshLoop: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []
    private var cleanedUp = false

    init(transport: MessageTransport, location: LocationService) {
        self.transport = transport
        self.locationService = location

        transport.onRemoteChange = { [weak self] in
            Task { await self?.refresh() }
        }
        // Posted by AppDelegate when a CloudKit push arrives.
        NotificationCenter.default.publisher(for: .aroundRemotePoke)
            .sink { [weak self] _ in
                Task { await self?.refresh() }
            }
            .store(in: &cancellables)
        location.$cellHash
            .compactMap { $0 }
            .removeDuplicates()
            .sink { [weak self] hash in self?.zoneChanged(to: hash) }
            .store(in: &cancellables)
    }

    func start(senderID: String) {
        locationService.start()
        guard refreshLoop == nil else { return }
        refreshLoop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(4))
            }
        }
        if !cleanedUp {
            cleanedUp = true
            Task {
                try? await transport.deleteMessages(
                    from: senderID,
                    olderThan: Date().addingTimeInterval(-MessageRules.timeToLive)
                )
            }
        }
    }

    private func zoneChanged(to hash: String) {
        zone = hash
        zones = Geohash.zoneAndNeighbors(hash)
        hasLoaded = false
        Task {
            await refresh()
            try? await transport.updateSubscriptions(zones: zones)
        }
    }

    func refresh() async {
        guard !zones.isEmpty else { return }
        let since = Date().addingTimeInterval(-MessageRules.timeToLive)
        do {
            let fetched = try await transport.fetch(zones: zones, since: since)
            allMessages = MessageRules.merge(allMessages, with: fetched)
            hasLoaded = true
        } catch {
            // Keep showing what we have; the next tick retries.
        }
        // Drop expired messages from the cache so the session's memory
        // footprint doesn't grow and nothing can resurface past its TTL.
        allMessages.removeAll { Date().timeIntervalSince($0.sentAt) >= MessageRules.timeToLive }
        messages = MessageRules.visible(allMessages, zones: Set(zones))
    }

    func send(text: String, senderID: String, senderName: String) async {
        guard let zone else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let message = Message(
            text: String(trimmed.prefix(500)),
            senderID: senderID,
            senderName: senderName,
            geohash: zone
        )
        // Optimistic append; rolled back if the send fails.
        allMessages = MessageRules.merge(allMessages, with: [message])
        messages = MessageRules.visible(allMessages, zones: Set(zones))
        do {
            try await transport.send(message)
        } catch {
            allMessages.removeAll { $0.id == message.id }
            messages = MessageRules.visible(allMessages, zones: Set(zones))
            sendError = error.localizedDescription
        }
    }

    var transportDescription: String { transport.kindDescription }
}

extension Notification.Name {
    static let aroundRemotePoke = Notification.Name("aroundRemotePoke")
}
