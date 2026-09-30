import Foundation

/// Sun position from the NOAA solar calculator equations
/// (https://gml.noaa.gov/grad/solcalc/calcdetails.html), accurate to well
/// under a minute for sunrise/sunset between 1800 and 2100.
public enum Solar {
    /// Altitude of the sun's centre at apparent sunrise/sunset: refraction
    /// (34') plus the solar disc radius (16').
    public static let sunriseAltitude = -0.833

    public enum TransitionKind: String { case sunrise, sunset }

    public struct Transition: Equatable {
        public let kind: TransitionKind
        public let date: Date
    }

    /// Geometric elevation of the sun above the horizon, in degrees.
    public static func elevation(at date: Date, latitude: Double, longitude: Double) -> Double {
        let julianDay = date.timeIntervalSince1970 / 86_400 + 2_440_587.5
        let t = (julianDay - 2_451_545) / 36_525

        let meanLongitude = (280.46646 + t * (36_000.76983 + t * 0.0003032))
            .truncatingRemainder(dividingBy: 360)
        let meanAnomaly = 357.52911 + t * (35_999.05029 - 0.0001537 * t)
        let eccentricity = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)
        let m = rad(meanAnomaly)
        let center = sin(m) * (1.914602 - t * (0.004817 + 0.000014 * t))
            + sin(2 * m) * (0.019993 - 0.000101 * t)
            + sin(3 * m) * 0.000289
        let omega = rad(125.04 - 1934.136 * t)
        let apparentLongitude = meanLongitude + center - 0.00569 - 0.00478 * sin(omega)
        let meanObliquity = 23 + (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60
        let obliquity = rad(meanObliquity + 0.00256 * cos(omega))
        let declination = asin(sin(obliquity) * sin(rad(apparentLongitude)))

        let y = pow(tan(obliquity / 2), 2)
        let l0 = rad(meanLongitude)
        let equationOfTime = 4 * deg(
            y * sin(2 * l0) - 2 * eccentricity * sin(m)
                + 4 * eccentricity * y * sin(m) * cos(2 * l0)
                - 0.5 * y * y * sin(4 * l0) - 1.25 * eccentricity * eccentricity * sin(2 * m))

        let utcMinutes = (date.timeIntervalSince1970 / 60).truncatingRemainder(dividingBy: 1440)
        var trueSolarMinutes = (utcMinutes + equationOfTime + 4 * longitude)
            .truncatingRemainder(dividingBy: 1440)
        if trueSolarMinutes < 0 { trueSolarMinutes += 1440 }
        let hourAngle = rad(trueSolarMinutes / 4 - 180)

        let lat = rad(latitude)
        let cosZenith = sin(lat) * sin(declination) + cos(lat) * cos(declination) * cos(hourAngle)
        return 90 - deg(acos(min(1, max(-1, cosZenith))))
    }

    /// Sunrise and sunset on the local calendar day containing `day`.
    /// Either is nil during polar day/night.
    public static func events(on day: Date, latitude: Double, longitude: Double,
                              timeZone: TimeZone = .current) -> (sunrise: Date?, sunset: Date?) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        let crossings = transitions(from: start, to: end, latitude: latitude, longitude: longitude)
        return (crossings.first { $0.kind == .sunrise }?.date,
                crossings.first { $0.kind == .sunset }?.date)
    }

    /// The next sunrise or sunset after `date`, searching up to two days ahead.
    public static func nextTransition(after date: Date, latitude: Double, longitude: Double) -> Transition? {
        transitions(from: date, to: date.addingTimeInterval(2 * 86_400),
                    latitude: latitude, longitude: longitude).first
    }

    /// Every crossing of the sunrise altitude in [start, end): scan in
    /// 10-minute steps, then bisect each sign change to under a second.
    static func transitions(from start: Date, to end: Date, latitude: Double, longitude: Double) -> [Transition] {
        func height(_ d: Date) -> Double {
            elevation(at: d, latitude: latitude, longitude: longitude) - sunriseAltitude
        }
        var result: [Transition] = []
        var a = start
        var ha = height(a)
        while a < end {
            let b = min(a.addingTimeInterval(600), end)
            let hb = height(b)
            if (ha < 0) != (hb < 0) {
                var lo = a, hi = b
                while hi.timeIntervalSince(lo) > 0.5 {
                    let mid = lo.addingTimeInterval(hi.timeIntervalSince(lo) / 2)
                    if (height(mid) < 0) == (ha < 0) { lo = mid } else { hi = mid }
                }
                result.append(Transition(kind: ha < 0 ? .sunrise : .sunset, date: hi))
            }
            a = b
            ha = hb
        }
        return result
    }

    private static func rad(_ d: Double) -> Double { d * .pi / 180 }
    private static func deg(_ r: Double) -> Double { r * 180 / .pi }
}
