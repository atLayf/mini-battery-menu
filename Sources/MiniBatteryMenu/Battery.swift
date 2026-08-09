import Foundation
import IOKit
import IOKit.ps

struct BatteryInfo {
    var percent: Int
    var isCharging: Bool
    var isPlugged: Bool
    var isCharged: Bool = false
    /// Minutes. nil when the system is still working it out.
    var minutesToEmpty: Int? = nil
    var minutesToFull: Int? = nil
    var cycleCount: Int? = nil
    var condition: String? = nil
    /// Maximum capacity as a percentage of the design capacity.
    var health: Int? = nil

    var isLow: Bool { !isPlugged && percent <= 20 }
    var isCritical: Bool { !isPlugged && percent <= 10 }
}

enum Battery {

    static func read() -> BatteryInfo? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }

        for source in sources {
            guard let d = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue()
                    as? [String: Any] else { continue }
            guard (d[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType else { continue }

            let current = d[kIOPSCurrentCapacityKey] as? Int ?? 0
            let maximum = d[kIOPSMaxCapacityKey] as? Int ?? 100
            let percent = maximum > 0 ? Int((Double(current) / Double(maximum) * 100).rounded()) : 0

            let state = d[kIOPSPowerSourceStateKey] as? String
            var info = BatteryInfo(
                percent: min(100, max(0, percent)),
                isCharging: d[kIOPSIsChargingKey] as? Bool ?? false,
                isPlugged: state == kIOPSACPowerValue,
                isCharged: d[kIOPSIsChargedKey] as? Bool ?? false,
                // -1 means "still calculating", which is not a duration.
                minutesToEmpty: positive(d[kIOPSTimeToEmptyKey] as? Int),
                minutesToFull: positive(d[kIOPSTimeToFullChargeKey] as? Int)
            )
            applyRegistryDetail(to: &info)
            return info
        }
        return nil
    }

    private static func positive(_ value: Int?) -> Int? {
        guard let value, value > 0 else { return nil }
        return value
    }

    /// Cycle count, condition and health are not in the power source snapshot,
    /// they come from the smart battery entry in the IO registry.
    private static func applyRegistryDetail(to info: inout BatteryInfo) {
        let service = IOServiceGetMatchingService(kIOMainPortDefault,
                                                  IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return }
        defer { IOObjectRelease(service) }

        var properties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = properties?.takeRetainedValue() as? [String: Any]
        else { return }

        info.cycleCount = dict["CycleCount"] as? Int

        // Apple Silicon reports health under NominalChargeCapacity against
        // DesignCapacity; Intel used MaxCapacity.
        let design = dict["DesignCapacity"] as? Int
        let nominal = (dict["NominalChargeCapacity"] as? Int) ?? (dict["AppleRawMaxCapacity"] as? Int)
        if let design, design > 0, let nominal {
            info.health = Int((Double(nominal) / Double(design) * 100).rounded())
        }

        if let permanentFailure = dict["PermanentFailureStatus"] as? Int, permanentFailure != 0 {
            info.condition = "Service Battery"
        } else {
            info.condition = "Normal"
        }
    }

    /// "3:12" from 192 minutes.
    static func duration(_ minutes: Int) -> String {
        String(format: "%d:%02d", minutes / 60, minutes % 60)
    }
}
