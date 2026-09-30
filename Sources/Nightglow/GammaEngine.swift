import CoreGraphics
import NightglowCore

/// Tints every online display by scaling its ColorSync gamma table.
/// macOS drops these tables when the owning process exits, so a crash can
/// never leave the screen stuck orange.
final class GammaEngine {
    private var originals: [CGDirectDisplayID: GammaRamp] = [:]

    static func onlineDisplays() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &ids, &count) == .success else { return [] }
        return Array(ids.prefix(Int(count)))
    }

    static func readRamp(_ display: CGDirectDisplayID) -> GammaRamp? {
        let capacity = CGDisplayGammaTableCapacity(display)
        guard capacity > 0 else { return nil }
        var r = [CGGammaValue](repeating: 0, count: Int(capacity))
        var g = r, b = r
        var count: UInt32 = 0
        guard CGGetDisplayTransferByTable(display, capacity, &r, &g, &b, &count) == .success,
              count > 0 else { return nil }
        let n = Int(count)
        return GammaRamp(red: Array(r.prefix(n)), green: Array(g.prefix(n)), blue: Array(b.prefix(n)))
    }

    /// Reset to ColorSync and re-read every display's calibrated table.
    /// Call on launch, display changes and wake, before re-applying.
    func recapture() {
        CGDisplayRestoreColorSyncSettings()
        originals = [:]
        for id in Self.onlineDisplays() {
            originals[id] = Self.readRamp(id)
        }
    }

    /// Returns the number of displays that accepted the table.
    @discardableResult
    func apply(_ setting: DisplaySetting) -> Int {
        var applied = 0
        for id in Self.onlineDisplays() {
            if originals[id] == nil { originals[id] = Self.readRamp(id) }
            guard let original = originals[id] else { continue }
            let t = original.applying(setting)
            if CGSetDisplayTransferByTable(id, UInt32(t.red.count), t.red, t.green, t.blue) == .success {
                applied += 1
            }
        }
        return applied
    }

    func original(for display: CGDirectDisplayID) -> GammaRamp? { originals[display] }

    func restore() {
        CGDisplayRestoreColorSyncSettings()
    }
}
