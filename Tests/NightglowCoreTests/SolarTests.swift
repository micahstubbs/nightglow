import XCTest
@testable import NightglowCore

final class SolarTests: XCTestCase {
    private func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: iso)!
    }

    private func assertClose(_ actual: Date?, _ expected: String, minutes: Double = 3,
                             file: StaticString = #filePath, line: UInt = #line) {
        guard let actual else { return XCTFail("expected \(expected), got nil", file: file, line: line) }
        let delta = abs(actual.timeIntervalSince(date(expected))) / 60
        XCTAssertLessThan(delta, minutes, "\(actual) vs \(expected)", file: file, line: line)
    }

    private func maxElevation(on day: String, latitude: Double, longitude: Double) -> Double {
        let start = date(day)
        return stride(from: 0.0, to: 86_400, by: 60).map {
            Solar.elevation(at: start.addingTimeInterval($0), latitude: latitude, longitude: longitude)
        }.max()!
    }

    func testEquinoxNoonElevationEqualsNinetyMinusLatitude() {
        XCTAssertEqual(maxElevation(on: "2026-03-20T00:00:00Z", latitude: 0, longitude: 0), 90, accuracy: 1)
        XCTAssertEqual(maxElevation(on: "2026-03-20T00:00:00Z", latitude: 40, longitude: 0), 50, accuracy: 1)
    }

    func testSolsticeNoonElevationInSanFrancisco() {
        // 90 - 37.77 + 23.44
        XCTAssertEqual(maxElevation(on: "2024-06-21T07:00:00Z", latitude: 37.7749, longitude: -122.4194),
                       75.66, accuracy: 0.5)
    }

    func testSanFranciscoSummerSolsticeSunriseAndSunset() {
        let tz = TimeZone(identifier: "America/Los_Angeles")!
        let events = Solar.events(on: date("2024-06-21T12:00:00-07:00"), latitude: 37.7749,
                                  longitude: -122.4194, timeZone: tz)
        assertClose(events.sunrise, "2024-06-21T05:48:00-07:00")
        assertClose(events.sunset, "2024-06-21T20:34:30-07:00")
    }

    func testLondonWinterSolsticeSunriseAndSunset() {
        let tz = TimeZone(identifier: "Europe/London")!
        let events = Solar.events(on: date("2024-12-21T12:00:00Z"), latitude: 51.5074,
                                  longitude: -0.1278, timeZone: tz)
        assertClose(events.sunrise, "2024-12-21T08:04:00Z")
        assertClose(events.sunset, "2024-12-21T15:53:00Z")
    }

    func testPolarNightHasNoSunriseOrSunset() {
        let tz = TimeZone(identifier: "Europe/Oslo")!
        let events = Solar.events(on: date("2024-12-21T12:00:00+01:00"), latitude: 69.6492,
                                  longitude: 18.9553, timeZone: tz)
        XCTAssertNil(events.sunrise)
        XCTAssertNil(events.sunset)
    }

    func testNextTransitionAfterNoonIsSunset() {
        let now = date("2024-06-21T12:00:00-07:00")
        let next = Solar.nextTransition(after: now, latitude: 37.7749, longitude: -122.4194)
        XCTAssertEqual(next?.kind, .sunset)
        assertClose(next?.date, "2024-06-21T20:34:30-07:00")
    }
}
