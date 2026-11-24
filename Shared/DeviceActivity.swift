import ActivityKit

/// Shared between the app and the widget extension: Live Activity attributes
/// for the Dynamic Island / Lock Screen monitor.
struct DeviceActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var cpuPercent: Double   // 0...100
        var memPercent: Double   // 0...100
        var batteryPercent: Int  // 0...100, -1 unknown
        var charging: Bool
        var netDownBps: Double   // bytes per second
        var netUpBps: Double     // bytes per second
        // Which metrics the user chose to show on the island
        var showCPU: Bool
        var showMem: Bool
        var showBatt: Bool
        var showNet: Bool
    }

    var deviceName: String
}
