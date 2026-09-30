import Foundation

public struct RGB: Equatable {
    public var r: Double
    public var g: Double
    public var b: Double

    public init(r: Double, g: Double, b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }
}

/// Black-body colour for a correlated colour temperature, using Tanner
/// Helland's curve fit of Mitchell Charity's blackbody table, rescaled so
/// 6500 K (display white) is exactly (1, 1, 1) and no channel exceeds 1.
public enum ColorTemperature {
    public static let minKelvin = 1200.0
    public static let maxKelvin = 10_000.0
    public static let neutralKelvin = 6500.0

    private static let neutral = helland(neutralKelvin)

    public static func rgb(kelvin: Double) -> RGB {
        let k = clampKelvin(kelvin)
        let raw = helland(k)
        var c = RGB(r: raw.r / neutral.r, g: raw.g / neutral.g, b: raw.b / neutral.b)
        let peak = max(c.r, c.g, c.b)
        c = RGB(r: c.r / peak, g: c.g / peak, b: c.b / peak)
        return c
    }

    public static func clampKelvin(_ k: Double) -> Double { min(maxKelvin, max(minKelvin, k)) }

    /// Raw 0...255 channel values.
    private static func helland(_ kelvin: Double) -> RGB {
        let t = kelvin / 100
        let r = t <= 66 ? 255 : 329.698727446 * pow(t - 60, -0.1332047592)
        let g = t <= 66
            ? 99.4708025861 * log(t) - 161.1195681661
            : 288.1221695283 * pow(t - 60, -0.0755148492)
        let b: Double
        if t >= 66 { b = 255 } else if t <= 19 { b = 0 } else { b = 138.5177312231 * log(t - 10) - 305.0447927307 }
        func clamp(_ v: Double) -> Double { min(255, max(0, v)) }
        return RGB(r: clamp(r), g: clamp(g), b: clamp(b))
    }
}

/// What to show on the displays right now.
public struct DisplaySetting: Equatable {
    public static let minBrightness = 0.1

    public var kelvin: Double
    public var brightness: Double

    public init(kelvin: Double, brightness: Double) {
        self.kelvin = ColorTemperature.clampKelvin(kelvin)
        self.brightness = min(1, max(Self.minBrightness, brightness))
    }

    public static let neutral = DisplaySetting(kelvin: ColorTemperature.neutralKelvin, brightness: 1)

    /// Per-channel gain combining colour temperature and dimming.
    public var multipliers: RGB {
        let c = ColorTemperature.rgb(kelvin: kelvin)
        return RGB(r: c.r * brightness, g: c.g * brightness, b: c.b * brightness)
    }
}

/// Day/night targets, blended by solar elevation the way Redshift does:
/// full day above +3°, full night below -6° (civil twilight), linear between.
public struct Schedule: Equatable {
    public var dayKelvin: Double
    public var nightKelvin: Double
    public var dayBrightness: Double
    public var nightBrightness: Double
    public var dayElevation: Double
    public var nightElevation: Double

    public init(dayKelvin: Double = 6500, nightKelvin: Double = 3400,
                dayBrightness: Double = 1, nightBrightness: Double = 1,
                dayElevation: Double = 3, nightElevation: Double = -6) {
        self.dayKelvin = dayKelvin
        self.nightKelvin = nightKelvin
        self.dayBrightness = dayBrightness
        self.nightBrightness = nightBrightness
        self.dayElevation = dayElevation
        self.nightElevation = nightElevation
    }

    /// 1 in full daylight, 0 at night.
    public func dayFraction(elevation: Double) -> Double {
        if elevation >= dayElevation { return 1 }
        if elevation <= nightElevation { return 0 }
        return (elevation - nightElevation) / (dayElevation - nightElevation)
    }

    public func setting(elevation: Double) -> DisplaySetting {
        let f = dayFraction(elevation: elevation)
        let day = DisplaySetting(kelvin: dayKelvin, brightness: dayBrightness)
        let night = DisplaySetting(kelvin: nightKelvin, brightness: nightBrightness)
        return DisplaySetting(kelvin: night.kelvin + (day.kelvin - night.kelvin) * f,
                              brightness: night.brightness + (day.brightness - night.brightness) * f)
    }
}

/// A display's per-channel transfer table (CGGetDisplayTransferByTable).
public struct GammaRamp: Equatable {
    public var red: [Float]
    public var green: [Float]
    public var blue: [Float]

    public init(red: [Float], green: [Float], blue: [Float]) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// Scale the display's own (ColorSync-calibrated) ramp rather than
    /// replacing it, so calibration survives the tint.
    public func applying(_ setting: DisplaySetting) -> GammaRamp {
        let m = setting.multipliers
        return GammaRamp(red: red.map { $0 * Float(m.r) },
                         green: green.map { $0 * Float(m.g) },
                         blue: blue.map { $0 * Float(m.b) })
    }
}
