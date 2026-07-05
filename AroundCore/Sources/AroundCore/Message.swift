import Foundation

/// A single ephemeral chat message, bound to a geohash zone.
public struct Message: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let text: String
    public let senderID: String
    public let senderName: String
    public let geohash: String
    public let sentAt: Date

    public init(
        id: String = UUID().uuidString,
        text: String,
        senderID: String,
        senderName: String,
        geohash: String,
        sentAt: Date = .now
    ) {
        self.id = id
        self.text = text
        self.senderID = senderID
        self.senderName = senderName
        self.geohash = geohash
        self.sentAt = sentAt
    }
}

/// Rules for which messages are visible: zone membership, TTL, dedupe, ordering.
public enum MessageRules {
    /// Messages fade 24 hours after being sent.
    public static let timeToLive: TimeInterval = 24 * 60 * 60

    /// Consecutive messages from the same sender within this window are grouped visually.
    public static let groupingWindow: TimeInterval = 120

    public static func expiryDate(of message: Message) -> Date {
        message.sentAt.addingTimeInterval(timeToLive)
    }

    /// True when `message` continues a visual group started by `previous`: same
    /// sender, sent after `previous`, and within `groupingWindow` of it.
    public static func continuesGroup(_ message: Message, after previous: Message?) -> Bool {
        guard let previous else { return false }
        guard message.senderID == previous.senderID else { return false }
        let gap = message.sentAt.timeIntervalSince(previous.sentAt)
        return gap >= 0 && gap <= groupingWindow
    }

    /// Filters to unexpired messages in the given zones, deduplicates by id,
    /// and sorts oldest-first (chat order). Messages timestamped more than
    /// 5 minutes in the future are dropped as clock-skew garbage.
    public static func visible(_ messages: [Message], zones: Set<String>, asOf now: Date = .now) -> [Message] {
        var seen = Set<String>()
        return messages
            .filter { message in
                zones.contains(message.geohash)
                    && now.timeIntervalSince(message.sentAt) < timeToLive
                    && message.sentAt.timeIntervalSince(now) < 5 * 60
                    && seen.insert(message.id).inserted
            }
            .sorted { ($0.sentAt, $0.id) < ($1.sentAt, $1.id) }
    }

    /// Merges a fetched batch into an existing list (new wins on id collision).
    public static func merge(_ existing: [Message], with incoming: [Message]) -> [Message] {
        var byID = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
        for message in incoming { byID[message.id] = message }
        return Array(byID.values)
    }
}
