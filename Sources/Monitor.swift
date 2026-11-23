import Foundation
import UIKit
import Network

struct BatteryDetails {
    var cycleCount: Int?
    var designCapacity: Int?
    var maxCapacity: Int?
    var currentCapacity: Int?
    var voltageMV: Int?
    var temperatureC: Double?
    var isChargingHW: Bool?
    var healthPercent: Double? {
        guard let m = maxCapacity, let d = designCapacity, d > 0 else { return nil }
        return Double(m) / Double(d) * 100.0
    }
}

struct InterfaceInfo: Identifiable {
    var id: String { name + ip }
    let name: String
    let ip: String
    let isV6: Bool
}

@MainActor
final class Monitor: ObservableObject {
    // Live metrics
    @Published var cpuTotal: Double = 0            // 0...1
    @Published var cpuPerCore: [Double] = []
    @Published var cpuHistory: [Double] = []       // last 60 samples, percent
    @Published var memUsedFraction: Double = 0
    @Published var memUsed: UInt64 = 0
    @Published var memFree: UInt64 = 0
    @Published var appFootprint: UInt64 = 0
    @Published var memHistory: [Double] = []
    @Published var batteryLevel: Float = -1
    @Published var batteryState: UIDevice.BatteryState = .unknown
    @Published var lowPower: Bool = false
    @Published var batteryDetails = BatteryDetails()
    @Published var thermal: ProcessInfo.ThermalState = .nominal
    @Published var storageTotal: UInt64 = 0
    @Published var storageFree: UInt64 = 0
    @Published var uptime: TimeInterval = 0
    @Published var interfaces: [InterfaceInfo] = []
    @Published var tunnelDetected: Bool = false
    @Published var pathDescription: String = "—"
    @Published var wifiBytes: (in: UInt64, out: UInt64) = (0, 0)
    @Published var cellBytes: (in: UInt64, out: UInt64) = (0, 0)
    @Published var netDownBps: Double = 0   // bytes per second, all interfaces
    @Published var netUpBps: Double = 0

    private var prevTraffic: (in: UInt64, out: UInt64, time: TimeInterval)?

    @Published var islandOn: Bool = false

    private var timer: Timer?
    private var tickCount: Int = 0
    private var prevTicks: [[Int32]]?
    private let pathMonitor = NWPathMonitor()
    private let pathQueue = DispatchQueue(label: "devicescope.path")

    init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        startPathMonitor()
        refreshSlow()
        sample()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sample()
                if Int(Date().timeIntervalSince1970) % 10 == 0 { self?.refreshSlow() }
            }
        }
    }

    deinit { timer?.invalidate(); pathMonitor.cancel() }

    private func startPathMonitor() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            let desc: String
            if path.status != .satisfied {
                desc = "无连接"
            } else if path.usesInterfaceType(.wifi) {
                desc = "Wi-Fi"
            } else if path.usesInterfaceType(.cellular) {
                desc = "蜂窝网络"
            } else if path.usesInterfaceType(.wiredEthernet) {
                desc = "有线以太网"
            } else {
                desc = "其他"
            }
            Task { @MainActor in self?.pathDescription = desc }
        }
        pathMonitor.start(queue: pathQueue)
    }

    // MARK: - Sampling

    private func sample() {
        if let cpu = sampleCPU() {
            cpuTotal = cpu.total
            cpuPerCore = cpu.perCore
            cpuHistory.append(cpu.total * 100)
            if cpuHistory.count > 60 { cpuHistory.removeFirst(cpuHistory.count - 60) }
        }
        let mem = memoryStats()
        memUsed = mem.used
        memFree = mem.free
        appFootprint = mem.app
        memUsedFraction = mem.total > 0 ? Double(mem.used) / Double(mem.total) : 0
        memHistory.append(memUsedFraction * 100)
        if memHistory.count > 60 { memHistory.removeFirst(memHistory.count - 60) }

        batteryLevel = UIDevice.current.batteryLevel
        batteryState = UIDevice.current.batteryState
        lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        thermal = ProcessInfo.processInfo.thermalState
        uptime = ProcessInfo.processInfo.systemUptime

        // Real-time network throughput from interface counter deltas
        let t = Self.trafficCounters()
        let totalIn = t.wifi.0 + t.cell.0
        let totalOut = t.wifi.1 + t.cell.1
        let now = Date().timeIntervalSince1970
        if let p = prevTraffic {
            let dt = now - p.time
            if dt > 0 {
                netDownBps = totalIn >= p.in ? Double(totalIn - p.in) / dt : 0
                netUpBps = totalOut >= p.out ? Double(totalOut - p.out) / dt : 0
            }
        }
        prevTraffic = (totalIn, totalOut, now)

        tickCount += 1
        if islandOn && tickCount % 5 == 0 {
            LiveActivityController.shared.update(islandState())
        }
    }

    // MARK: - Dynamic Island Live Activity

    func islandState() -> DeviceActivityAttributes.ContentState {
        DeviceActivityAttributes.ContentState(
            cpuPercent: cpuTotal * 100,
            memPercent: memUsedFraction * 100,
            batteryPercent: batteryLevel >= 0 ? Int(batteryLevel * 100) : -1,
            charging: batteryState == .charging || batteryState == .full
        )
    }

    func toggleIsland() {
        if islandOn {
            LiveActivityController.shared.stop()
            islandOn = false
        } else {
            LiveActivityController.shared.start(deviceName: DeviceInfo.marketingName, state: islandState())
            islandOn = LiveActivityController.shared.isRunning
        }
    }

    private func refreshSlow() {
        batteryDetails = Self.readBatteryDetails()
        let s = Self.storageStats()
        storageTotal = s.total
        storageFree = s.free
        interfaces = Self.interfaceList()
        tunnelDetected = Self.tunnelActive()
        let t = Self.trafficCounters()
        wifiBytes = t.wifi
        cellBytes = t.cell
    }

    // MARK: - CPU (host_processor_info)

    private func sampleCPU() -> (total: Double, perCore: [Double])? {
        var numCPUs: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCpuInfo: mach_msg_type_number_t = 0
        let err = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUs, &cpuInfo, &numCpuInfo)
        guard err == KERN_SUCCESS, let info = cpuInfo else { return nil }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: info)),
                          vm_size_t(Int(numCpuInfo) * MemoryLayout<integer_t>.size))
        }
        let stride = Int(CPU_STATE_MAX)
        var current: [[Int32]] = []
        for i in 0..<Int(numCPUs) {
            var ticks: [Int32] = []
            for j in 0..<stride { ticks.append(info[i * stride + j]) }
            current.append(ticks)
        }
        guard let prev = prevTicks, prev.count == current.count else {
            prevTicks = current
            return (0, Array(repeating: 0, count: current.count))
        }
        prevTicks = current
        var perCore: [Double] = []
        var totalUsed: Double = 0
        var totalAll: Double = 0
        for i in 0..<current.count {
            let du = Double(current[i][Int(CPU_STATE_USER)] - prev[i][Int(CPU_STATE_USER)])
            let ds = Double(current[i][Int(CPU_STATE_SYSTEM)] - prev[i][Int(CPU_STATE_SYSTEM)])
            let dn = Double(current[i][Int(CPU_STATE_NICE)] - prev[i][Int(CPU_STATE_NICE)])
            let di = Double(current[i][Int(CPU_STATE_IDLE)] - prev[i][Int(CPU_STATE_IDLE)])
            let used = du + ds + dn
            let all = used + di
            perCore.append(all > 0 ? used / all : 0)
            totalUsed += used
            totalAll += all
        }
        return (totalAll > 0 ? totalUsed / totalAll : 0, perCore)
    }

    // MARK: - Memory (host_statistics64 + task_vm_info)

    private func memoryStats() -> (total: UInt64, used: UInt64, free: UInt64, app: UInt64) {
        let total = ProcessInfo.processInfo.physicalMemory
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &stats) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        var used: UInt64 = 0
        var free: UInt64 = 0
        if kr == KERN_SUCCESS {
            let page = UInt64(vm_kernel_page_size)
            free = UInt64(stats.free_count) * page
            used = (UInt64(stats.active_count) + UInt64(stats.inactive_count)
                + UInt64(stats.speculative_count) + UInt64(stats.wire_count)
                + UInt64(stats.compressor_page_count)) * page
            if used > total { used = total }
        }
        var info = task_vm_info_data_t()
        var c2 = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let kr2 = withUnsafeMutablePointer(to: &info) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(c2)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &c2)
            }
        }
        return (total, used, free, kr2 == KERN_SUCCESS ? info.phys_footprint : 0)
    }

    // MARK: - Storage

    private static func storageStats() -> (total: UInt64, free: UInt64) {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        if let values = try? url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]),
           let total = values.volumeTotalCapacity,
           let free = values.volumeAvailableCapacityForImportantUsage {
            return (UInt64(total), UInt64(free))
        }
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
           let total = attrs[.systemSize] as? UInt64,
           let free = attrs[.systemFreeSize] as? UInt64 {
            return (total, free)
        }
        return (0, 0)
    }

    // MARK: - Battery via IOKit (AppleSmartBattery, dynamically loaded:
    // the iOS SDK ships no Swift module for IOKit, so resolve the C symbols at runtime)

    private static func readBatteryDetails() -> BatteryDetails {
        var d = BatteryDetails()
        guard let handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY) else { return d }
        defer { dlclose(handle) }

        typealias MatchingFn = @convention(c) (UnsafePointer<CChar>) -> UnsafeMutableRawPointer?
        typealias GetServiceFn = @convention(c) (UInt32, UnsafeRawPointer) -> UInt32
        typealias CreatePropsFn = @convention(c) (UInt32, UnsafeMutablePointer<UnsafeMutableRawPointer?>, UnsafeRawPointer?, UInt32) -> Int32
        typealias ReleaseFn = @convention(c) (UInt32) -> Int32

        guard let matchingSym = dlsym(handle, "IOServiceMatching"),
              let getServiceSym = dlsym(handle, "IOServiceGetMatchingService"),
              let createPropsSym = dlsym(handle, "IORegistryEntryCreateCFProperties"),
              let releaseSym = dlsym(handle, "IOObjectRelease") else { return d }
        let matching = unsafeBitCast(matchingSym, to: MatchingFn.self)
        let getService = unsafeBitCast(getServiceSym, to: GetServiceFn.self)
        let createProps = unsafeBitCast(createPropsSym, to: CreatePropsFn.self)
        let release = unsafeBitCast(releaseSym, to: ReleaseFn.self)

        var mainPort: UInt32 = 0
        if let sym = dlsym(handle, "kIOMainPortDefault") {
            mainPort = sym.load(as: UInt32.self)
        }
        guard let dictPtr = "AppleSmartBattery".withCString({ matching($0) }) else { return d }
        let matchingDict = Unmanaged<CFMutableDictionary>.fromOpaque(dictPtr).takeRetainedValue()
        // IOServiceGetMatchingService consumes one reference of the matching dictionary.
        let svc = getService(mainPort, Unmanaged.passRetained(matchingDict).toOpaque())
        if svc == 0 { return d }
        defer { _ = release(svc) }

        var propsPtr: UnsafeMutableRawPointer? = nil
        let allocPtr: UnsafeRawPointer? = kCFAllocatorDefault.map { UnsafeRawPointer(Unmanaged.passUnretained($0).toOpaque()) }
        guard createProps(svc, &propsPtr, allocPtr, 0) == 0, let rawProps = propsPtr,
              let dict = Unmanaged<CFMutableDictionary>.fromOpaque(rawProps).takeRetainedValue() as? [String: Any] else { return d }
        d.cycleCount = dict["CycleCount"] as? Int
        d.designCapacity = dict["DesignCapacity"] as? Int
        d.maxCapacity = (dict["AppleRawMaxCapacity"] as? Int) ?? (dict["MaxCapacity"] as? Int)
        d.currentCapacity = (dict["AppleRawCurrentCapacity"] as? Int) ?? (dict["CurrentCapacity"] as? Int)
        d.voltageMV = dict["Voltage"] as? Int
        if let t = dict["Temperature"] as? Int { d.temperatureC = Double(t) / 100.0 }
        d.isChargingHW = dict["IsCharging"] as? Bool
        return d
    }

    // MARK: - Network interfaces & traffic

    private static func interfaceList() -> [InterfaceInfo] {
        var result: [InterfaceInfo] = []
        var addrList: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addrList) == 0, let first = addrList else { return [] }
        defer { freeifaddrs(addrList) }
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let cur = ptr {
            let ifa = cur.pointee
            if let sa = ifa.ifa_addr {
                let family = sa.pointee.sa_family
                if family == sa_family_t(AF_INET) || family == sa_family_t(AF_INET6) {
                    var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(sa, socklen_t(sa.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
                    let name = String(cString: ifa.ifa_name)
                    if name != "lo0" {
                        result.append(InterfaceInfo(name: name, ip: String(cString: host), isV6: family == sa_family_t(AF_INET6)))
                    }
                }
            }
            ptr = cur.pointee.ifa_next
        }
        return result
    }

    private static func trafficCounters() -> (wifi: (UInt64, UInt64), cell: (UInt64, UInt64)) {
        var wifi: (UInt64, UInt64) = (0, 0)
        var cell: (UInt64, UInt64) = (0, 0)
        var addrList: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addrList) == 0, let first = addrList else { return (wifi, cell) }
        defer { freeifaddrs(addrList) }
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let cur = ptr {
            let ifa = cur.pointee
            if let sa = ifa.ifa_addr, sa.pointee.sa_family == sa_family_t(AF_LINK), let raw = ifa.ifa_data {
                let data = raw.assumingMemoryBound(to: if_data.self).pointee
                let name = String(cString: ifa.ifa_name)
                if name == "en0" {
                    wifi = (UInt64(data.ifi_ibytes), UInt64(data.ifi_obytes))
                } else if name.hasPrefix("pdp_ip") {
                    cell.0 += UInt64(data.ifi_ibytes)
                    cell.1 += UInt64(data.ifi_obytes)
                }
            }
            ptr = cur.pointee.ifa_next
        }
        return (wifi, cell)
    }

    private static func tunnelActive() -> Bool {
        guard let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any],
              let scoped = settings["__SCOPED__"] as? [String: Any] else { return false }
        for key in scoped.keys {
            if key.contains("utun") || key.contains("tap") || key.contains("tun") || key.contains("ppp") || key.contains("ipsec") {
                return true
            }
        }
        return false
    }
}
