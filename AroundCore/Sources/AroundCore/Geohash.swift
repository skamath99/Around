import Foundation

/// Geohash encoding/decoding and neighbor lookup.
///
/// Around uses precision-7 geohashes (~153 m × 153 m cells) as chat zones.
/// A device's "room" is its own cell plus the 8 surrounding cells, so two
/// people standing on either side of a cell border still see each other.
public enum Geohash {
    /// Cell edge is ~153 m at this precision.
    public static let zonePrecision = 7

    private static let base32 = Array("0123456789bcdefghjkmnpqrstuvwxyz")
    private static let base32Lookup: [Character: Int] = {
        var map: [Character: Int] = [:]
        for (i, c) in base32.enumerated() { map[c] = i }
        return map
    }()

    public struct Bounds: Equatable, Sendable {
        public var latitudeRange: ClosedRange<Double>
        public var longitudeRange: ClosedRange<Double>

        public var center: (latitude: Double, longitude: Double) {
            (
                (latitudeRange.lowerBound + latitudeRange.upperBound) / 2,
                (longitudeRange.lowerBound + longitudeRange.upperBound) / 2
            )
        }
    }

    // MARK: - Encoding

    public static func encode(latitude: Double, longitude: Double, length: Int = zonePrecision) -> String {
        precondition(length > 0)
        var latRange = (-90.0, 90.0)
        var lonRange = (-180.0, 180.0)
        var hash = ""
        var bit = 0
        var value = 0
        var evenBit = true

        while hash.count < length {
            if evenBit {
                let mid = (lonRange.0 + lonRange.1) / 2
                if longitude >= mid {
                    value = (value << 1) | 1
                    lonRange.0 = mid
                } else {
                    value <<= 1
                    lonRange.1 = mid
                }
            } else {
                let mid = (latRange.0 + latRange.1) / 2
                if latitude >= mid {
                    value = (value << 1) | 1
                    latRange.0 = mid
                } else {
                    value <<= 1
                    latRange.1 = mid
                }
            }
            evenBit.toggle()
            bit += 1
            if bit == 5 {
                hash.append(base32[value])
                bit = 0
                value = 0
            }
        }
        return hash
    }

    // MARK: - Decoding

    public static func decode(_ hash: String) -> Bounds? {
        var latRange = (-90.0, 90.0)
        var lonRange = (-180.0, 180.0)
        var evenBit = true

        for char in hash.lowercased() {
            guard let value = base32Lookup[char] else { return nil }
            for shift in stride(from: 4, through: 0, by: -1) {
                let bit = (value >> shift) & 1
                if evenBit {
                    let mid = (lonRange.0 + lonRange.1) / 2
                    if bit == 1 { lonRange.0 = mid } else { lonRange.1 = mid }
                } else {
                    let mid = (latRange.0 + latRange.1) / 2
                    if bit == 1 { latRange.0 = mid } else { latRange.1 = mid }
                }
                evenBit.toggle()
            }
        }
        return Bounds(
            latitudeRange: latRange.0...latRange.1,
            longitudeRange: lonRange.0...lonRange.1
        )
    }

    // MARK: - Neighbors

    public enum Direction: CaseIterable, Sendable {
        case north, south, east, west
    }

    private static let neighborTable: [Direction: [String]] = [
        .north: ["p0r21436x8zb9dcf5h7kjnmqesgutwvy", "bc01fg45238967deuvhjyznpkmstqrwx"],
        .south: ["14365h7k9dcfesgujnmqp0r2twvyx8zb", "238967debc01fg45kmstqrwxuvhjyznp"],
        .east:  ["bc01fg45238967deuvhjyznpkmstqrwx", "p0r21436x8zb9dcf5h7kjnmqesgutwvy"],
        .west:  ["238967debc01fg45kmstqrwxuvhjyznp", "14365h7k9dcfesgujnmqp0r2twvyx8zb"],
    ]

    private static let borderTable: [Direction: [String]] = [
        .north: ["prxz", "bcfguvyz"],
        .south: ["028b", "0145hjnp"],
        .east:  ["bcfguvyz", "prxz"],
        .west:  ["0145hjnp", "028b"],
    ]

    /// The adjacent cell in the given direction, or nil for invalid input.
    public static func adjacent(_ hash: String, _ direction: Direction) -> String? {
        let hash = hash.lowercased()
        guard let last = hash.last, base32Lookup[last] != nil else { return nil }
        var parent = String(hash.dropLast())
        let type = hash.count % 2 // 1 = odd length, 0 = even

        if borderTable[direction]![type].contains(last), !parent.isEmpty {
            guard let adjustedParent = adjacent(parent, direction) else { return nil }
            parent = adjustedParent
        }
        guard let index = neighborTable[direction]![type].firstIndex(of: last) else { return nil }
        let position = neighborTable[direction]![type].distance(from: neighborTable[direction]![type].startIndex, to: index)
        return parent + String(base32[position])
    }

    /// The cell itself plus its 8 surrounding cells. Used as the "room" a
    /// device listens to, so cell borders don't split conversations.
    public static func zoneAndNeighbors(_ hash: String) -> [String] {
        guard let north = adjacent(hash, .north),
              let south = adjacent(hash, .south),
              let east = adjacent(hash, .east),
              let west = adjacent(hash, .west),
              let northEast = adjacent(north, .east),
              let northWest = adjacent(north, .west),
              let southEast = adjacent(south, .east),
              let southWest = adjacent(south, .west)
        else { return [hash] }
        return [hash, north, northEast, east, southEast, south, southWest, west, northWest]
    }
}
