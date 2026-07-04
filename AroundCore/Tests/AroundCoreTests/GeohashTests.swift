import XCTest
@testable import AroundCore

final class GeohashTests: XCTestCase {

    // MARK: - Known vectors

    func testEncodeKnownVectors() {
        // Classic reference points from the geohash literature.
        XCTAssertEqual(Geohash.encode(latitude: 57.64911, longitude: 10.40744, length: 11), "u4pruydqqvj")
        XCTAssertEqual(Geohash.encode(latitude: 42.605, longitude: -5.603, length: 5), "ezs42")
        XCTAssertEqual(Geohash.encode(latitude: 37.7749, longitude: -122.4194, length: 7).count, 7)
    }

    func testDecodeContainsOriginalPoint() {
        let points: [(Double, Double)] = [
            (37.7749, -122.4194), (0, 0), (-33.8688, 151.2093), (78.22, 15.65), (-54.8, -68.3),
        ]
        for (lat, lon) in points {
            let hash = Geohash.encode(latitude: lat, longitude: lon)
            let bounds = Geohash.decode(hash)
            XCTAssertNotNil(bounds, "decode failed for \(hash)")
            XCTAssertTrue(bounds!.latitudeRange.contains(lat))
            XCTAssertTrue(bounds!.longitudeRange.contains(lon))
        }
    }

    func testDecodeRejectsInvalidCharacters() {
        XCTAssertNil(Geohash.decode("9q8yyka")) // 'a' is not in the geohash alphabet
        XCTAssertNil(Geohash.decode("hello!"))
    }

    func testPrecision7CellIsRoughly150Meters() {
        let hash = Geohash.encode(latitude: 37.7749, longitude: -122.4194, length: 7)
        let bounds = Geohash.decode(hash)!
        let latMeters = (bounds.latitudeRange.upperBound - bounds.latitudeRange.lowerBound) * 111_320
        XCTAssertEqual(latMeters, 153, accuracy: 5)
    }

    // MARK: - Neighbors

    func testAdjacentRoundTrips() {
        let hash = Geohash.encode(latitude: 37.7749, longitude: -122.4194)
        for direction in Geohash.Direction.allCases {
            let opposite: Geohash.Direction = switch direction {
            case .north: .south
            case .south: .north
            case .east: .west
            case .west: .east
            }
            let neighbor = Geohash.adjacent(hash, direction)
            XCTAssertNotNil(neighbor)
            XCTAssertEqual(Geohash.adjacent(neighbor!, opposite), hash)
        }
    }

    func testAdjacentMovesInTheRightDirection() {
        let hash = Geohash.encode(latitude: 37.7749, longitude: -122.4194)
        let center = Geohash.decode(hash)!.center
        let north = Geohash.decode(Geohash.adjacent(hash, .north)!)!.center
        let east = Geohash.decode(Geohash.adjacent(hash, .east)!)!.center
        XCTAssertGreaterThan(north.latitude, center.latitude)
        XCTAssertEqual(north.longitude, center.longitude, accuracy: 1e-9)
        XCTAssertGreaterThan(east.longitude, center.longitude)
        XCTAssertEqual(east.latitude, center.latitude, accuracy: 1e-9)
    }

    func testAdjacentWrapsAcrossDateline() {
        let hash = Geohash.encode(latitude: 0, longitude: 179.9999)
        let east = Geohash.adjacent(hash, .east)
        XCTAssertNotNil(east)
        XCTAssertEqual(Geohash.adjacent(east!, .west), hash)
        let eastCenter = Geohash.decode(east!)!.center
        XCTAssertLessThan(eastCenter.longitude, 0, "east of the dateline should be negative longitude")
    }

    func testZoneAndNeighborsReturnsNineUniqueCells() {
        let hash = Geohash.encode(latitude: 37.7749, longitude: -122.4194)
        let zones = Geohash.zoneAndNeighbors(hash)
        XCTAssertEqual(zones.count, 9)
        XCTAssertEqual(Set(zones).count, 9)
        XCTAssertEqual(zones.first, hash)
        for zone in zones {
            XCTAssertEqual(zone.count, hash.count)
        }
    }

    func testNeighboringPointsShareARoom() {
        // Two people ~40 m apart but straddling a cell border must still
        // appear in each other's room (own cell + 8 neighbors).
        let a = Geohash.encode(latitude: 37.77490, longitude: -122.41940)
        var b = a
        var offset = 0.0002 // ~22 m
        while b == a { // walk east until we cross a cell border
            b = Geohash.encode(latitude: 37.77490, longitude: -122.41940 + offset)
            offset += 0.0002
        }
        XCTAssertTrue(Geohash.zoneAndNeighbors(a).contains(b))
        XCTAssertTrue(Geohash.zoneAndNeighbors(b).contains(a))
    }
}
