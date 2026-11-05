import Foundation
import CoreLocation

/// Plain spherical maths for the running games. Haversine is plenty at
/// running distances.
enum Geo {
    private static let earthRadius = 6_371_000.0

    static func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let lat1 = a.latitude * .pi / 180, lat2 = b.latitude * .pi / 180
        let dLat = lat2 - lat1
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earthRadius * asin(min(1, sqrt(h)))
    }

    /// Compass bearing from `a` to `b`, degrees clockwise from north.
    static func bearing(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let lat1 = a.latitude * .pi / 180, lat2 = b.latitude * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let degrees = atan2(y, x) * 180 / .pi
        return (degrees + 360).truncatingRemainder(dividingBy: 360)
    }

    /// The point `meters` away from `origin` along `bearing`.
    static func offset(_ origin: CLLocationCoordinate2D, meters: Double, bearing: Double) -> CLLocationCoordinate2D {
        let radians = bearing * .pi / 180
        let dLat = meters * cos(radians) / 111_320
        let dLon = meters * sin(radians) / (111_320 * max(0.2, cos(origin.latitude * .pi / 180)))
        return CLLocationCoordinate2D(latitude: origin.latitude + dLat, longitude: origin.longitude + dLon)
    }

    /// "north-east", for spoken directions.
    static func compassWord(_ bearing: Double) -> String {
        let words = ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]
        return words[Int((bearing + 22.5) / 45) % 8]
    }

    /// "NE", for the screen.
    static func compassShort(_ bearing: Double) -> String {
        let words = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        return words[Int((bearing + 22.5) / 45) % 8]
    }
}

/// The map, cut into blocks about 170 m on a side. Every GPS run claims the
/// blocks it passes through; the Territory game makes a game of it.
enum TerritoryGrid {
    /// North-south size of a block in degrees (about 167 m).
    static let cellDegrees = 0.0015

    /// Approximate area of one block, for "you own 1.2 km²".
    static let cellSquareKm = 0.167 * 0.167

    private static func lonStep(row: Int) -> Double {
        let centerLat = (Double(row) + 0.5) * cellDegrees
        return cellDegrees / max(0.2, cos(centerLat * .pi / 180))
    }

    static func cell(for coordinate: CLLocationCoordinate2D) -> String {
        let row = Int(floor(coordinate.latitude / cellDegrees))
        let col = Int(floor(coordinate.longitude / lonStep(row: row)))
        return "\(row)_\(col)"
    }

    /// Corner points of a block, for drawing it on a map.
    static func polygon(for id: String) -> [CLLocationCoordinate2D] {
        let parts = id.split(separator: "_").compactMap { Int($0) }
        guard parts.count == 2 else { return [] }
        let row = parts[0], col = parts[1]
        let step = lonStep(row: row)
        let lat0 = Double(row) * cellDegrees, lat1 = lat0 + cellDegrees
        let lon0 = Double(col) * step, lon1 = lon0 + step
        return [
            CLLocationCoordinate2D(latitude: lat0, longitude: lon0),
            CLLocationCoordinate2D(latitude: lat0, longitude: lon1),
            CLLocationCoordinate2D(latitude: lat1, longitude: lon1),
            CLLocationCoordinate2D(latitude: lat1, longitude: lon0),
        ]
    }

    /// Centre of a block.
    static func center(of id: String) -> CLLocationCoordinate2D? {
        let corners = polygon(for: id)
        guard corners.count == 4 else { return nil }
        return CLLocationCoordinate2D(
            latitude: (corners[0].latitude + corners[2].latitude) / 2,
            longitude: (corners[0].longitude + corners[2].longitude) / 2
        )
    }

    /// Every block a route touched. Long gaps between fixes are filled in
    /// every 40 m so a block isn't skipped between two points.
    static func cells(along route: [CLLocationCoordinate2D]) -> Set<String> {
        var cells = Set<String>()
        guard let first = route.first else { return cells }
        cells.insert(cell(for: first))
        for (a, b) in zip(route, route.dropFirst()) {
            let gap = Geo.distance(a, b)
            let steps = max(1, Int(gap / 40))
            for step in 1...steps {
                let f = Double(step) / Double(steps)
                cells.insert(cell(for: CLLocationCoordinate2D(
                    latitude: a.latitude + (b.latitude - a.latitude) * f,
                    longitude: a.longitude + (b.longitude - a.longitude) * f
                )))
            }
        }
        return cells
    }
}
