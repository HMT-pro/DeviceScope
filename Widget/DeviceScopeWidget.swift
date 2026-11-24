import WidgetKit
import SwiftUI
import ActivityKit

@main
struct DeviceScopeWidgetBundle: WidgetBundle {
    var body: some Widget {
        DeviceScopeLiveActivity()
    }
}

// MARK: - User-selected metrics

private struct IslandMetric: Identifiable {
    let id: String
    let label: String
    let value: String
    let color: Color
}

private func rateText(_ bps: Double) -> String {
    if bps < 1024 { return String(format: "%.0fB/s", bps) }
    if bps < 1024 * 1024 { return String(format: "%.0fK/s", bps / 1024) }
    return String(format: "%.1fM/s", bps / 1024 / 1024)
}

private func metrics(for s: DeviceActivityAttributes.ContentState) -> [IslandMetric] {
    var list: [IslandMetric] = []
    if s.showCPU {
        list.append(IslandMetric(id: "cpu", label: "CPU",
                                 value: String(format: "%.0f%%", s.cpuPercent), color: .orange))
    }
    if s.showMem {
        list.append(IslandMetric(id: "mem", label: "内存",
                                 value: String(format: "%.0f%%", s.memPercent), color: .purple))
    }
    if s.showBatt {
        list.append(IslandMetric(id: "batt", label: s.charging ? "电量⚡" : "电量",
                                 value: s.batteryPercent >= 0 ? "\(s.batteryPercent)%" : "—", color: .green))
    }
    if s.showNet {
        list.append(IslandMetric(id: "net", label: "网速",
                                 value: "↓\(rateText(s.netDownBps)) ↑\(rateText(s.netUpBps))", color: .blue))
    }
    if list.isEmpty {
        list.append(IslandMetric(id: "cpu", label: "CPU",
                                 value: String(format: "%.0f%%", s.cpuPercent), color: .orange))
    }
    return list
}

struct DeviceScopeLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DeviceActivityAttributes.self) { context in
            // Lock Screen / banner presentation
            let ms = metrics(for: context.state)
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.deviceName)
                        .font(.caption).foregroundStyle(.secondary)
                    Text("DeviceScope 监控中")
                        .font(.headline)
                }
                Spacer()
                ForEach(ms.prefix(3)) { metric in
                    StatView(label: metric.label, value: metric.value, color: metric.color)
                }
            }
            .padding()
        } dynamicIsland: { context in
            let ms = metrics(for: context.state)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    if let first = ms.first {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(first.label).font(.caption2).foregroundStyle(.secondary)
                            Text(first.value)
                                .font(.title3.bold().monospacedDigit())
                                .foregroundStyle(first.color)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if ms.count > 1 {
                        let second = ms[1]
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(second.label).font(.caption2).foregroundStyle(.secondary)
                            Text(second.value)
                                .font(.title3.bold().monospacedDigit())
                                .foregroundStyle(second.color)
                        }
                    } else {
                        Text("DeviceScope").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(ms.dropFirst(2)) { metric in
                            HStack {
                                Text(metric.label).font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Text(metric.value)
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(metric.color)
                            }
                        }
                        if context.state.showMem {
                            ProgressView(value: min(max(context.state.memPercent, 0), 100), total: 100)
                                .tint(.purple)
                        }
                    }
                }
            } compactLeading: {
                if let first = ms.first {
                    Text(first.value)
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(first.color)
                }
            } compactTrailing: {
                if ms.count > 1 {
                    Text(ms[1].value)
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(ms[1].color)
                } else {
                    Image(systemName: "gauge.with.dots.needle.67percent")
                        .foregroundStyle(.orange)
                }
            } minimal: {
                Image(systemName: "gauge.with.dots.needle.67percent")
                    .foregroundStyle(.orange)
            }
            .keylineTint(.orange)
        }
    }
}

private struct StatView: View {
    let label: String
    let value: String
    let color: Color
    var body: some View {
        VStack(spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.headline.monospacedDigit()).foregroundStyle(color)
        }
    }
}
