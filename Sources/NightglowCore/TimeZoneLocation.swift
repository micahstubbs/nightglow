import Foundation

public struct Coordinate: Equatable, Codable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// Approximate location from the system time zone, using the reference
/// city coordinates in the tz database's zone.tab. Needs no permission and
/// is close enough for sunrise/sunset (a few minutes per 100 km).
public enum TimeZoneLocation {
    public static let systemZoneTab = "/usr/share/zoneinfo/zone.tab"

    public static func coordinate(for identifier: String = TimeZone.current.identifier,
                                  zoneTab: String? = nil) -> Coordinate? {
        let text = zoneTab ?? (try? String(contentsOfFile: systemZoneTab, encoding: .utf8)) ?? ""
        for line in text.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") { continue }
            let fields = trimmed.split(separator: "\t")
            guard fields.count >= 3, fields[2] == identifier else { continue }
            return parseISO6709(String(fields[1]))
        }
        return nil
    }

    /// "+DDMM+DDDMM" or "+DDMMSS+DDDMMSS".
    static func parseISO6709(_ s: String) -> Coordinate? {
        guard let split = s.dropFirst().firstIndex(where: { $0 == "+" || $0 == "-" }) else { return nil }
        let lat = String(s[s.startIndex..<split])
        let lon = String(s[split...])
        guard let latitude = degrees(lat, degreeDigits: 2),
              let longitude = degrees(lon, degreeDigits: 3) else { return nil }
        return Coordinate(latitude: latitude, longitude: longitude)
    }

    private static func degrees(_ s: String, degreeDigits: Int) -> Double? {
        guard let sign = s.first, sign == "+" || sign == "-" else { return nil }
        let digits = Array(s.dropFirst())
        guard digits.count == degreeDigits + 2 || digits.count == degreeDigits + 4,
              digits.allSatisfy(\.isNumber) else { return nil }
        func number(_ from: Int, _ count: Int) -> Double { Double(String(digits[from..<from + count]))! }
        var value = number(0, degreeDigits) + number(degreeDigits, 2) / 60
        if digits.count == degreeDigits + 4 { value += number(degreeDigits + 2, 2) / 3600 }
        return sign == "-" ? -value : value
    }
}
