import XCTest
@testable import AroundCore

final class MessageRulesTests: XCTestCase {
    let zone = "9q8yyk8"
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func message(
        id: String = UUID().uuidString,
        text: String = "hi",
        zone: String? = nil,
        ageHours: Double
    ) -> Message {
        Message(
            id: id,
            text: text,
            senderID: "sender",
            senderName: "amber-fox-42",
            geohash: zone ?? self.zone,
            sentAt: now.addingTimeInterval(-ageHours * 3600)
        )
    }

    func testExpiredMessagesAreHidden() {
        let fresh = message(ageHours: 23.9)
        let stale = message(ageHours: 24.1)
        let visible = MessageRules.visible([fresh, stale], zones: [zone], asOf: now)
        XCTAssertEqual(visible.map(\.id), [fresh.id])
    }

    func testMessagesFromOtherZonesAreHidden() {
        let here = message(ageHours: 1)
        let elsewhere = message(zone: "u4pruyd", ageHours: 1)
        let visible = MessageRules.visible([here, elsewhere], zones: [zone], asOf: now)
        XCTAssertEqual(visible.map(\.id), [here.id])
    }

    func testNeighborZonesAreVisibleWhenIncluded() {
        let neighborZone = Geohash.adjacent(zone, .north)!
        let neighborMessage = message(zone: neighborZone, ageHours: 1)
        let zones = Set(Geohash.zoneAndNeighbors(zone))
        XCTAssertEqual(
            MessageRules.visible([neighborMessage], zones: zones, asOf: now).count, 1
        )
    }

    func testFarFutureTimestampsAreDropped() {
        let skewed = message(ageHours: -1) // "sent" an hour from now
        let slightlyAhead = message(ageHours: -0.02) // ~1 min ahead: allowed
        let visible = MessageRules.visible([skewed, slightlyAhead], zones: [zone], asOf: now)
        XCTAssertEqual(visible.map(\.id), [slightlyAhead.id])
    }

    func testDeduplicatesByID() {
        let original = message(id: "dup", ageHours: 2)
        let copy = message(id: "dup", ageHours: 2)
        XCTAssertEqual(MessageRules.visible([original, copy], zones: [zone], asOf: now).count, 1)
    }

    func testSortsOldestFirst() {
        let a = message(id: "a", ageHours: 3)
        let b = message(id: "b", ageHours: 1)
        let c = message(id: "c", ageHours: 2)
        let visible = MessageRules.visible([a, b, c], zones: [zone], asOf: now)
        XCTAssertEqual(visible.map(\.id), ["a", "c", "b"])
    }

    func testMergePrefersIncoming() {
        let original = message(id: "m", text: "old", ageHours: 1)
        let updated = message(id: "m", text: "new", ageHours: 1)
        let merged = MessageRules.merge([original], with: [updated])
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged.first?.text, "new")
    }

    func testMergeKeepsDistinctMessages() {
        let a = message(id: "a", ageHours: 1)
        let b = message(id: "b", ageHours: 2)
        XCTAssertEqual(Set(MessageRules.merge([a], with: [b]).map(\.id)), ["a", "b"])
    }

    func testExpiryDateIs24HoursAfterSend() {
        let m = message(ageHours: 0)
        XCTAssertEqual(MessageRules.expiryDate(of: m), m.sentAt.addingTimeInterval(86_400))
    }
}

final class HandleGeneratorTests: XCTestCase {
    struct SeededGenerator: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }
    }

    func testHandleFormat() {
        for _ in 0..<50 {
            let handle = HandleGenerator.random()
            XCTAssertNotNil(
                handle.range(of: #"^[a-z]+-[a-z]+-\d{1,2}$"#, options: .regularExpression),
                "unexpected handle format: \(handle)"
            )
        }
    }

    func testDeterministicWithSeededGenerator() {
        var a = SeededGenerator(state: 7)
        var b = SeededGenerator(state: 7)
        XCTAssertEqual(HandleGenerator.random(using: &a), HandleGenerator.random(using: &b))
    }
}
