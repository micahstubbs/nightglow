import XCTest
@testable import NightglowCore

final class ColorTemperatureTests: XCTestCase {
    func testDaylightIsNeutralWhite() {
        let c = ColorTemperature.rgb(kelvin: 6500)
        XCTAssertEqual(c.r, 1, accuracy: 0.001)
        XCTAssertEqual(c.g, 1, accuracy: 0.001)
        XCTAssertEqual(c.b, 1, accuracy: 0.001)
    }

    func testHalogenIsWarm() {
        let c = ColorTemperature.rgb(kelvin: 3400)
        XCTAssertEqual(c.r, 1, accuracy: 0.001)
        XCTAssertTrue((0.65...0.85).contains(c.g), "g=\(c.g)")
        XCTAssertTrue((0.45...0.65).contains(c.b), "b=\(c.b)")
    }

    func testCandleHasAlmostNoBlue() {
        let c = ColorTemperature.rgb(kelvin: 1900)
        XCTAssertEqual(c.r, 1, accuracy: 0.001)
        XCTAssertLessThan(c.b, 0.1)
    }

    func testCoolTemperatureCapsBlueAtOne() {
        let c = ColorTemperature.rgb(kelvin: 10_000)
        XCTAssertEqual(c.b, 1, accuracy: 0.001)
        XCTAssertLessThan(c.r, 1)
    }

    func testWarmerMeansLessBlue() {
        let temps: [Double] = [6500, 5500, 4500, 3400, 2700, 2000]
        let blues = temps.map { ColorTemperature.rgb(kelvin: $0).b }
        XCTAssertEqual(blues, blues.sorted(by: >))
    }
}

final class ScheduleTests: XCTestCase {
    let schedule = Schedule(dayKelvin: 6500, nightKelvin: 3400, dayBrightness: 1, nightBrightness: 0.8)

    func testFullDayAboveThreeDegrees() {
        let s = schedule.setting(elevation: 20)
        XCTAssertEqual(s.kelvin, 6500)
        XCTAssertEqual(s.brightness, 1)
    }

    func testFullNightBelowMinusSixDegrees() {
        let s = schedule.setting(elevation: -20)
        XCTAssertEqual(s.kelvin, 3400)
        XCTAssertEqual(s.brightness, 0.8)
    }

    func testTwilightInterpolatesLinearly() {
        XCTAssertEqual(schedule.dayFraction(elevation: -1.5), 0.5, accuracy: 1e-9)
        let s = schedule.setting(elevation: -1.5)
        XCTAssertEqual(s.kelvin, 4950, accuracy: 1e-6)
        XCTAssertEqual(s.brightness, 0.9, accuracy: 1e-9)
    }

    func testValuesAreClamped() {
        let wild = Schedule(dayKelvin: 50_000, nightKelvin: 100, dayBrightness: 3, nightBrightness: 0)
        XCTAssertEqual(wild.setting(elevation: 90).kelvin, ColorTemperature.maxKelvin)
        XCTAssertEqual(wild.setting(elevation: -90).kelvin, ColorTemperature.minKelvin)
        XCTAssertEqual(wild.setting(elevation: 90).brightness, 1)
        XCTAssertEqual(wild.setting(elevation: -90).brightness, DisplaySetting.minBrightness)
    }
}

final class GammaRampTests: XCTestCase {
    func testScalesOriginalRampPerChannel() {
        let original = GammaRamp(red: [0, 0.5, 1], green: [0, 0.5, 1], blue: [0, 0.5, 1])
        let setting = DisplaySetting(kelvin: 3400, brightness: 0.8)
        let m = setting.multipliers
        let out = original.applying(setting)
        XCTAssertEqual(out.red, [0, Float(0.4), Float(0.8)])
        XCTAssertEqual(out.green[2], Float(m.g), accuracy: 1e-6)
        XCTAssertEqual(out.blue[1], Float(0.5 * m.b), accuracy: 1e-6)
        XCTAssertEqual(m.r, 0.8, accuracy: 1e-9)
    }

    func testNeutralSettingLeavesCalibratedRampUntouched() {
        let original = GammaRamp(red: [0.02, 0.51, 0.97], green: [0, 0.49, 1], blue: [0.01, 0.5, 0.99])
        XCTAssertEqual(original.applying(DisplaySetting(kelvin: 6500, brightness: 1)), original)
    }
}

final class TimeZoneLocationTests: XCTestCase {
    let zoneTab = """
    # comment line
    US\t+340308-1181434\tAmerica/Los_Angeles\tPacific
    GB\t+513030-0000731\tEurope/London
    JP\t+353916+1394441\tAsia/Tokyo
    AU\t-3352+15113\tAustralia/Sydney\tNew South Wales (most areas)
    """

    func testParsesSecondsPrecisionCoordinates() {
        let c = TimeZoneLocation.coordinate(for: "America/Los_Angeles", zoneTab: zoneTab)
        XCTAssertEqual(c?.latitude ?? 0, 34.0522, accuracy: 0.001)
        XCTAssertEqual(c?.longitude ?? 0, -118.2428, accuracy: 0.001)
    }

    func testParsesMinutesPrecisionAndSouthernHemisphere() {
        let c = TimeZoneLocation.coordinate(for: "Australia/Sydney", zoneTab: zoneTab)
        XCTAssertEqual(c?.latitude ?? 0, -33.8667, accuracy: 0.001)
        XCTAssertEqual(c?.longitude ?? 0, 151.2167, accuracy: 0.001)
    }

    func testUnknownZoneIsNil() {
        XCTAssertNil(TimeZoneLocation.coordinate(for: "Mars/Olympus_Mons", zoneTab: zoneTab))
    }

    func testSystemZoneTabResolvesCurrentMacZone() {
        XCTAssertNotNil(TimeZoneLocation.coordinate(for: "America/Los_Angeles"))
    }
}
