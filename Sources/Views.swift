import SwiftUI
import Charts
import CoreMotion

struct ContentView: View {
    var body: some View {
        TabView {
            OverviewView()
                .tabItem { Label("总览", systemImage: "gauge.with.dots.needle.67percent") }
            MonitorView()
                .tabItem { Label("监控", systemImage: "waveform.path.ecg") }
            BatteryView()
                .tabItem { Label("电池", systemImage: "battery.100percent") }
            NetworkView()
                .tabItem { Label("网络", systemImage: "network") }
            SensorsView()
                .tabItem { Label("传感器", systemImage: "sensor.tag.radiowaves.forward") }
        }
    }
}

// MARK: - Shared rows

struct InfoRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
    }
}

struct GaugeBar: View {
    let title: String
    let fraction: Double
    let detail: String
    var color: Color = .blue
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Text(detail).font(.subheadline.monospacedDigit())
            }
            ProgressView(value: min(max(fraction, 0), 1))
                .tint(color)
        }
    }
}

// MARK: - Overview

struct OverviewView: View {
    @EnvironmentObject var m: Monitor
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 4) {
                        Image(systemName: "iphone")
                            .font(.system(size: 44))
                            .foregroundStyle(.blue)
                        Text(DeviceInfo.marketingName)
                            .font(.title3.bold())
                        Text(DeviceInfo.modelIdentifier)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                Section("设备") {
                    InfoRow(label: "设备名称", value: DeviceInfo.deviceName)
                    InfoRow(label: "芯片", value: DeviceInfo.chipName)
                    InfoRow(label: "CPU 核心", value: "\(DeviceInfo.cpuCores) 核")
                    InfoRow(label: "内存", value: DeviceInfo.formatBytes(DeviceInfo.totalRAM))
                    InfoRow(label: "系统", value: "\(DeviceInfo.systemName) \(DeviceInfo.systemVersion) (\(DeviceInfo.osBuild))")
                    InfoRow(label: "屏幕", value: String(format: "%.0f × %.0f pt · @%.0fx", DeviceInfo.screenInfo.points.width, DeviceInfo.screenInfo.points.height, DeviceInfo.screenInfo.scale))
                    InfoRow(label: "开机时间", value: DeviceInfo.formatUptime(m.uptime))
                }
                Section("实时状态") {
                    GaugeBar(title: "电量", fraction: m.batteryLevel >= 0 ? Double(m.batteryLevel) : 0,
                             detail: m.batteryLevel >= 0 ? "\(Int(m.batteryLevel * 100))%" : "—",
                             color: .green)
                    GaugeBar(title: "CPU", fraction: m.cpuTotal,
                             detail: String(format: "%.1f%%", m.cpuTotal * 100), color: .orange)
                    GaugeBar(title: "内存", fraction: m.memUsedFraction,
                             detail: "\(DeviceInfo.formatBytes(m.memUsed)) / \(DeviceInfo.formatBytes(DeviceInfo.totalRAM))",
                             color: .purple)
                    if m.storageTotal > 0 {
                        GaugeBar(title: "存储", fraction: Double(m.storageTotal - m.storageFree) / Double(m.storageTotal),
                                 detail: "可用 \(DeviceInfo.formatBytes(m.storageFree)) / \(DeviceInfo.formatBytes(m.storageTotal))",
                                 color: .teal)
                    }
                    InfoRow(label: "热状态", value: thermalText(m.thermal))
                    InfoRow(label: "低电量模式", value: m.lowPower ? "开启" : "关闭")
                }
            }
            .navigationTitle("DeviceScope")
        }
    }

    func thermalText(_ t: ProcessInfo.ThermalState) -> String {
        switch t {
        case .nominal: return "正常"
        case .fair: return "轻微发热"
        case .serious: return "发热严重"
        case .critical: return "过热警告"
        @unknown default: return "未知"
        }
    }
}

// MARK: - Monitor (charts)

struct MonitorView: View {
    @EnvironmentObject var m: Monitor
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("灵动岛实时活动").font(.headline)
                            Text(m.islandOn ? "运行中：岛上显示 CPU / 内存 / 电量" : "把 CPU、电量钉在灵动岛和锁屏上")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(m.islandOn ? "停止" : "开启") { m.toggleIsland() }
                            .buttonStyle(.borderedProminent)
                            .tint(m.islandOn ? .red : .orange)
                    }
                    .padding(.vertical, 4)
                } footer: {
                    Text("实时活动由系统托管，应用退到后台后数据更新会变慢；锁屏也会同步显示。")
                }
                Section("CPU 使用率（最近 60 秒）") {
                    Chart(Array(m.cpuHistory.enumerated()), id: \.offset) { item in
                        LineMark(x: .value("秒", item.offset), y: .value("%", item.element))
                            .foregroundStyle(.orange)
                        AreaMark(x: .value("秒", item.offset), y: .value("%", item.element))
                            .foregroundStyle(.orange.opacity(0.15))
                    }
                    .chartYScale(domain: 0...100)
                    .frame(height: 120)
                    InfoRow(label: "总占用", value: String(format: "%.1f%%", m.cpuTotal * 100))
                    ForEach(Array(m.cpuPerCore.enumerated()), id: \.offset) { core in
                        GaugeBar(title: "核心 \(core.offset + 1)", fraction: core.element,
                                 detail: String(format: "%.0f%%", core.element * 100), color: .orange)
                    }
                }
                Section("内存使用率（最近 60 秒）") {
                    Chart(Array(m.memHistory.enumerated()), id: \.offset) { item in
                        LineMark(x: .value("秒", item.offset), y: .value("%", item.element))
                            .foregroundStyle(.purple)
                        AreaMark(x: .value("秒", item.offset), y: .value("%", item.element))
                            .foregroundStyle(.purple.opacity(0.15))
                    }
                    .chartYScale(domain: 0...100)
                    .frame(height: 120)
                    InfoRow(label: "已用", value: DeviceInfo.formatBytes(m.memUsed))
                    InfoRow(label: "空闲", value: DeviceInfo.formatBytes(m.memFree))
                    InfoRow(label: "本应用占用", value: DeviceInfo.formatBytes(m.appFootprint))
                }
            }
            .navigationTitle("实时监控")
        }
    }
}

// MARK: - Battery

struct BatteryView: View {
    @EnvironmentObject var m: Monitor
    var body: some View {
        NavigationStack {
            List {
                Section("状态") {
                    InfoRow(label: "电量", value: m.batteryLevel >= 0 ? "\(Int(m.batteryLevel * 100))%" : "—")
                    InfoRow(label: "充电状态", value: stateText(m.batteryState))
                    InfoRow(label: "低电量模式", value: m.lowPower ? "开启" : "关闭")
                }
                Section("硬件信息（IOKit）") {
                    if let c = m.batteryDetails.cycleCount {
                        InfoRow(label: "循环次数", value: "\(c) 次")
                    }
                    if let h = m.batteryDetails.healthPercent {
                        InfoRow(label: "电池健康", value: String(format: "%.1f%%", h))
                    }
                    if let d = m.batteryDetails.designCapacity {
                        InfoRow(label: "设计容量", value: "\(d) mAh")
                    }
                    if let mx = m.batteryDetails.maxCapacity {
                        InfoRow(label: "当前满充容量", value: "\(mx) mAh")
                    }
                    if let cur = m.batteryDetails.currentCapacity {
                        InfoRow(label: "当前电量容量", value: "\(cur) mAh")
                    }
                    if let v = m.batteryDetails.voltageMV {
                        InfoRow(label: "电压", value: String(format: "%.2f V", Double(v) / 1000.0))
                    }
                    if let t = m.batteryDetails.temperatureC {
                        InfoRow(label: "电池温度", value: String(format: "%.1f °C", t))
                    }
                    if m.batteryDetails.cycleCount == nil {
                        Text("此设备未返回电池硬件数据")
                            .foregroundStyle(.secondary)
                    }
                }
                Section {
                    Text("循环次数与健康度来自 AppleSmartBattery 硬件寄存器，系统设置里看不到这么细。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("电池")
        }
    }

    func stateText(_ s: UIDevice.BatteryState) -> String {
        switch s {
        case .charging: return "充电中"
        case .full: return "已充满"
        case .unplugged: return "使用电池中"
        default: return "未知"
        }
    }
}

// MARK: - Network

func formatRate(_ bps: Double) -> String {
    if bps < 1024 { return String(format: "%.0f B/s", bps) }
    if bps < 1024 * 1024 { return String(format: "%.1f KB/s", bps / 1024) }
    if bps < 1024 * 1024 * 1024 { return String(format: "%.2f MB/s", bps / 1024 / 1024) }
    return String(format: "%.2f GB/s", bps / 1024 / 1024 / 1024)
}

struct NetworkView: View {
    @EnvironmentObject var m: Monitor
    var body: some View {
        NavigationStack {
            List {
                Section("连接") {
                    InfoRow(label: "当前网络", value: m.pathDescription)
                    InfoRow(label: "隧道接口（VPN/Loon 等）", value: m.tunnelDetected ? "已检测到" : "未检测到")
                }
                Section("实时网速") {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill").foregroundStyle(.green)
                        Text("下载").foregroundStyle(.secondary)
                        Spacer()
                        Text(formatRate(m.netDownBps)).font(.headline.monospacedDigit())
                    }
                    HStack {
                        Image(systemName: "arrow.up.circle.fill").foregroundStyle(.blue)
                        Text("上传").foregroundStyle(.secondary)
                        Spacer()
                        Text(formatRate(m.netUpBps)).font(.headline.monospacedDigit())
                    }
                }
                Section("流量（自开机累计）") {
                    InfoRow(label: "Wi-Fi 接收", value: DeviceInfo.formatBytes(m.wifiBytes.in))
                    InfoRow(label: "Wi-Fi 发送", value: DeviceInfo.formatBytes(m.wifiBytes.out))
                    InfoRow(label: "蜂窝 接收", value: DeviceInfo.formatBytes(m.cellBytes.in))
                    InfoRow(label: "蜂窝 发送", value: DeviceInfo.formatBytes(m.cellBytes.out))
                }
                Section("接口地址") {
                    ForEach(m.interfaces) { iface in
                        HStack {
                            Text(iface.name).foregroundStyle(.secondary)
                            Spacer()
                            Text(iface.ip)
                                .font(.callout.monospacedDigit())
                                .foregroundStyle(iface.isV6 ? .secondary : .primary)
                        }
                    }
                    if m.interfaces.isEmpty {
                        Text("暂无接口数据").foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("网络")
        }
    }
}

// MARK: - Sensors

struct SensorsView: View {
    @StateObject private var motion = MotionSampler()
    var body: some View {
        NavigationStack {
            List {
                Section("姿态（度）") {
                    InfoRow(label: "俯仰 Pitch", value: fmt(motion.pitch))
                    InfoRow(label: "横滚 Roll", value: fmt(motion.roll))
                    InfoRow(label: "偏航 Yaw", value: fmt(motion.yaw))
                }
                Section("加速度（g，含重力分量已分离）") {
                    InfoRow(label: "X", value: fmt(motion.accel.x, digits: 3))
                    InfoRow(label: "Y", value: fmt(motion.accel.y, digits: 3))
                    InfoRow(label: "Z", value: fmt(motion.accel.z, digits: 3))
                }
                Section("陀螺仪（rad/s）") {
                    InfoRow(label: "X", value: fmt(motion.gyro.x, digits: 3))
                    InfoRow(label: "Y", value: fmt(motion.gyro.y, digits: 3))
                    InfoRow(label: "Z", value: fmt(motion.gyro.z, digits: 3))
                }
                Section("磁力计（µT）") {
                    InfoRow(label: "X", value: fmt(motion.mag.x, digits: 1))
                    InfoRow(label: "Y", value: fmt(motion.mag.y, digits: 1))
                    InfoRow(label: "Z", value: fmt(motion.mag.z, digits: 1))
                }
                if motion.pressure > 0 {
                    Section("气压计") {
                        InfoRow(label: "气压", value: String(format: "%.2f kPa", motion.pressure))
                        InfoRow(label: "相对高度", value: String(format: "%.1f m", motion.relAltitude))
                    }
                }
            }
            .navigationTitle("传感器")
            .onAppear { motion.start() }
            .onDisappear { motion.stop() }
        }
    }

    func fmt(_ v: Double, digits: Int = 1) -> String {
        String(format: "%.\(digits)f", v)
    }
}

@MainActor
final class MotionSampler: ObservableObject {
    @Published var pitch: Double = 0
    @Published var roll: Double = 0
    @Published var yaw: Double = 0
    @Published var accel = CMAcceleration()
    @Published var gyro = CMRotationRate()
    @Published var mag = CMMagneticField()
    @Published var pressure: Double = 0
    @Published var relAltitude: Double = 0

    private let manager = CMMotionManager()
    private let altimeter = CMAltimeter()
    private let queue = OperationQueue()

    func start() {
        if manager.isDeviceMotionAvailable {
            manager.deviceMotionUpdateInterval = 0.1
            manager.startDeviceMotionUpdates(using: .xMagneticNorthZVertical, to: queue) { [weak self] data, _ in
                guard let data else { return }
                Task { @MainActor in
                    guard let self else { return }
                    self.pitch = data.attitude.pitch * 180 / .pi
                    self.roll = data.attitude.roll * 180 / .pi
                    self.yaw = data.attitude.yaw * 180 / .pi
                    self.accel = data.userAcceleration
                    self.gyro = data.rotationRate
                    self.mag = data.magneticField.field
                }
            }
        }
        if CMAltimeter.isRelativeAltitudeAvailable() {
            altimeter.startRelativeAltitudeUpdates(to: queue) { [weak self] data, _ in
                guard let data else { return }
                Task { @MainActor in
                    self?.pressure = data.pressure.doubleValue
                    self?.relAltitude = data.relativeAltitude.doubleValue
                }
            }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        altimeter.stopRelativeAltitudeUpdates()
    }
}
