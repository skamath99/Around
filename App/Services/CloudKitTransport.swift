import CloudKit
import Foundation
import AroundCore

/// Messages live as records in the CloudKit *public* database, so every
/// user of the app shares one pool, partitioned by geohash zone.
/// CKQuerySubscriptions make CloudKit send APNs pushes when a record is
/// created in a subscribed zone — no push server required.
@MainActor
final class CloudKitTransport: MessageTransport {
    static let containerID = "iCloud.com.sank.around"
    static let recordType = "Message"
    private static let subscriptionPrefix = "around-zone-"

    private let container: CKContainer
    private let database: CKDatabase

    let kindDescription = "iCloud public database"
    var onRemoteChange: (() -> Void)?

    init() {
        container = CKContainer(identifier: Self.containerID)
        database = container.publicCloudDatabase
    }

    func send(_ message: Message) async throws {
        guard (try? await container.accountStatus()) == .available else {
            throw TransportError.notSignedIn
        }
        let record = CKRecord(
            recordType: Self.recordType,
            recordID: CKRecord.ID(recordName: message.id)
        )
        record["text"] = message.text
        record["senderID"] = message.senderID
        record["senderName"] = message.senderName
        record["geohash"] = message.geohash
        record["sentAt"] = message.sentAt
        do {
            try await database.save(record)
        } catch {
            throw TransportError.underlying(Self.friendlyDescription(of: error))
        }
    }

    func fetch(zones: [String], since: Date) async throws -> [Message] {
        let query = CKQuery(
            recordType: Self.recordType,
            predicate: NSPredicate(format: "geohash IN %@ AND sentAt > %@", zones, since as NSDate)
        )
        query.sortDescriptors = [NSSortDescriptor(key: "sentAt", ascending: true)]

        var messages: [Message] = []
        var result = try await database.records(matching: query, resultsLimit: 200)
        while true {
            for (_, recordResult) in result.matchResults {
                if case .success(let record) = recordResult,
                   let message = Self.message(from: record) {
                    messages.append(message)
                }
            }
            guard let cursor = result.queryCursor else { break }
            result = try await database.records(continuingMatchFrom: cursor, resultsLimit: 200)
        }
        return messages
    }

    func updateSubscriptions(zones: [String]) async throws {
        let existing = try await database.allSubscriptions()
        let desired = Set(zones.map { Self.subscriptionPrefix + $0 })
        let existingIDs = Set(existing.map(\.subscriptionID))

        let stale = existingIDs
            .filter { $0.hasPrefix(Self.subscriptionPrefix) && !desired.contains($0) }
        let toCreate = zones.filter { !existingIDs.contains(Self.subscriptionPrefix + $0) }

        guard !stale.isEmpty || !toCreate.isEmpty else { return }

        let subscriptions = toCreate.map { zone -> CKSubscription in
            let subscription = CKQuerySubscription(
                recordType: Self.recordType,
                predicate: NSPredicate(format: "geohash == %@", zone),
                subscriptionID: Self.subscriptionPrefix + zone,
                options: .firesOnRecordCreation
            )
            let info = CKSubscription.NotificationInfo()
            info.titleLocalizationKey = "AROUND_NOTIFICATION_TITLE"
            info.titleLocalizationArgs = ["senderName"]
            info.alertLocalizationKey = "AROUND_NOTIFICATION_BODY"
            info.alertLocalizationArgs = ["text"]
            info.soundName = "default"
            // Included in the push payload so the app can suppress banners
            // for the user's own messages (CloudKit predicates can't do !=).
            info.desiredKeys = ["senderID"]
            info.shouldSendContentAvailable = true
            subscription.notificationInfo = info
            return subscription
        }
        _ = try await database.modifySubscriptions(saving: subscriptions, deleting: Array(stale))
    }

    func deleteMessages(from senderID: String, olderThan cutoff: Date) async throws {
        let query = CKQuery(
            recordType: Self.recordType,
            predicate: NSPredicate(format: "senderID == %@ AND sentAt < %@", senderID, cutoff as NSDate)
        )
        let result = try await database.records(matching: query, resultsLimit: 100)
        let ids = result.matchResults.map(\.0)
        guard !ids.isEmpty else { return }
        _ = try await database.modifyRecords(saving: [], deleting: ids)
    }

    private static func message(from record: CKRecord) -> Message? {
        guard let text = record["text"] as? String,
              let senderID = record["senderID"] as? String,
              let senderName = record["senderName"] as? String,
              let geohash = record["geohash"] as? String,
              let sentAt = record["sentAt"] as? Date
        else { return nil }
        return Message(
            id: record.recordID.recordName,
            text: text,
            senderID: senderID,
            senderName: senderName,
            geohash: geohash,
            sentAt: sentAt
        )
    }

    private static func friendlyDescription(of error: Error) -> String {
        guard let ckError = error as? CKError else { return error.localizedDescription }
        switch ckError.code {
        case .networkUnavailable, .networkFailure:
            return "You're offline — check your connection and try again."
        case .notAuthenticated:
            return TransportError.notSignedIn.errorDescription!
        case .quotaExceeded, .requestRateLimited:
            return "Around is busy right now — try again in a moment."
        default:
            return ckError.localizedDescription
        }
    }
}
