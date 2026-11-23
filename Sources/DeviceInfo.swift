import Foundation
import UIKit

/// Static device identification: model identifier, marketing name, SoC.
enum DeviceInfo {

    static var modelIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        var id = ""
        for child in mirror.children {
            if let value = child.value as? Int8, value != 0 {
                id.append(Character(UnicodeScalar(UInt8(value))))
            }
        }
        return id
    }

    /// identifier -> (marketing name, chip)
    private static let table: [String: (String, String)] = [
        "iPhone11,2": ("iPhone XS", "A12 Bionic"),
        "iPhone11,4": ("iPhone XS Max", "A12 Bionic"),
        "iPhone11,6": ("iPhone XS Max", "A12 Bionic"),
        "iPhone11,8": ("iPhone XR", "A12 Bionic"),
        "iPhone12,1": ("iPhone 11", "A13 Bionic"),
        "iPhone12,3": ("iPhone 11 Pro", "A13 Bionic"),
        "iPhone12,5": ("iPhone 11 Pro Max", "A13 Bionic"),
        "iPhone12,8": ("iPhone SE (2nd gen)", "A13 Bionic"),
        "iPhone13,1": ("iPhone 12 mini", "A14 Bionic"),
        "iPhone13,2": ("iPhone 12", "A14 Bionic"),
        "iPhone13,3": ("iPhone 12 Pro", "A14 Bionic"),
        "iPhone13,4": ("iPhone 12 Pro Max", "A14 Bionic"),
        "iPhone14,2": ("iPhone 13 Pro", "A15 Bionic"),
        "iPhone14,3": ("iPhone 13 Pro Max", "A15 Bionic"),
        "iPhone14,4": ("iPhone 13 mini", "A15 Bionic"),
        "iPhone14,5": ("iPhone 13", "A15 Bionic"),
        "iPhone14,6": ("iPhone SE (3rd gen)", "A15 Bionic"),
        "iPhone14,7": ("iPhone 14", "A15 Bionic"),
        "iPhone14,8": ("iPhone 14 Plus", "A15 Bionic"),
        "iPhone15,2": ("iPhone 14 Pro", "A16 Bionic"),
        "iPhone15,3": ("iPhone 14 Pro Max", "A16 Bionic"),
        "iPhone15,4": ("iPhone 15", "A16 Bionic"),
        "iPhone15,5": ("iPhone 15 Plus", "A16 Bionic"),
        "iPhone16,1": ("iPhone 15 Pro", "A17 Pro"),
        "iPhone16,2": ("iPhone 15 Pro Max", "A17 Pro"),
        "iPhone17,1": ("iPhone 16 Pro", "A18 Pro"),
        "iPhone17,2": ("iPhone 16 Pro Max", "A18 Pro"),
        "iPhone17,3": ("iPhone 16", "A18"),
        "iPhone17,4": ("iPhone 16 Plus", "A18"),
        "iPhone17,5": ("iPhone 16e", "A18"),
        "iPhone18,1": ("iPhone 17 Pro", "A19 Pro"),
        "iPhone18,2": ("iPhone 17 Pro Max", "A19 Pro"),
        "iPhone18,3": ("iPhone 17", "A19"),
        "iPhone18,4": ("iPhone Air", "A19 Pro"),
    ]

    static var marketingName: String {
        if modelIdentifier.hasPrefix("iPhone") || modelIdentifier.hasPrefix("iPad") {
            return table[modelIdentifier]?.0 ?? modelIdentifier
        }
        return UIDevice.current.model
    }

    static var chipName: String {
        table[modelIdentifier]?.1 ?? "—"
    }

    static var deviceName: String { UIDevice.current.name }
    static var systemName: String { UIDevice.current.systemName }
    static var systemVersion: String { UIDevice.current.systemVersion }

    static var osBuild: String {
        var size = 0
        sysctlbyname("kern.osversion", nil, &size, nil, 0)
        var buf = [CChar](repeating: 0, count: size)
        sysctlbyname("kern.osversion", &buf, &size, nil, 0)
        return String(cString: buf)
    }

    static var cpuCores: Int { ProcessInfo.processInfo.processorCount }
    static var totalRAM: UInt64 { ProcessInfo.processInfo.physicalMemory }

    static var screenInfo: (points: CGSize, scale: CGFloat, native: CGSize) {
        let bounds = UIScreen.main.bounds.size
        let scale = UIScreen.main.scale
        return (bounds, scale, CGSize(width: bounds.width * scale, height: bounds.height * scale))
    }

    static var bootDate: Date {
        Date(timeIntervalSinceNow: -ProcessInfo.processInfo.systemUptime)
    }

    static func formatBytes(_ bytes: UInt64) -> String {
        let f = ByteCountFormatter()
        f.countStyle = .binary
        return f.string(fromByteCount: Int64(bytes))
    }

    static func formatUptime(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let d = total / 86400
        let h = (total % 86400) / 3600
        let m = (total % 3600) / 60
        if d > 0 { return "\(d) 天 \(h) 小时 \(m) 分" }
        if h > 0 { return "\(h) 小时 \(m) 分" }
        return "\(m) 分"
    }
}
