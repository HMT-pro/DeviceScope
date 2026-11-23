import WidgetKit
import SwiftUI
import ActivityKit

@main
struct DeviceScopeWidgetBundle: WidgetBundle {
    var body: some Widget {
        DeviceScopeLiveActivity()
    }
}

struct DeviceScopeLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DeviceActivityAttributes.self) { context in
            // Lock Screen / banner presentation
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.deviceName)
                        .font(.caption).foregroundStyle(.secondary)
                    Text("DeviceScope 监控中")
                        .font(.headline)
                }
                Spacer()
                StatView(label: "CPU", value: String(format: "%.0f%%", context.state.cpuPercent), color: .orange)
                StatView(label: "内存", value: String(format: "%.0f%%", context.state.memPercent), color: .purple)
                StatView(label: "电量", value: context.state.batteryPercent >= 0 ? "\(context.state.batteryPercent)%" : "—", color: .green)
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CPU").font(.caption2).foregroundStyle(.secondary)
                        Text(String(format: "%.0f%%", context.state.cpuPercent))
                            .font(.title3.bold().monospacedDigit())
                            .foregroundStyle(.orange)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("电量").font(.caption2).foregroundStyle(.secondary)
                        HStack(spacing: 2) {
                            if context.state.charging {
                                Image(systemName: "bolt.fill").font(.caption2).foregroundStyle(.yellow)
                            }
                            Text(context.state.batteryPercent >= 0 ? "\(context.state.batteryPercent)%" : "—")
                                .font(.title3.bold().monospacedDigit())
                                .foregroundStyle(.green)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("内存占用").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.0f%%", context.state.memPercent))
                                .font(.caption.monospacedDigit())
                        }
                        ProgressView(value: min(max(context.state.memPercent, 0), 100), total: 100)
                            .tint(.purple)
                    }
                }
            } compactLeading: {
                Text(String(format: "%.0f%%", context.state.cpuPercent))
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(.orange)
            } compactTrailing: {
                HStack(spacing: 1) {
                    Image(systemName: context.state.charging ? "battery.100percent.bolt" : "battery.100percent")
                        .font(.caption2)
                    Text(context.state.batteryPercent >= 0 ? "\(context.state.batteryPercent)" : "—")
                        .font(.caption.bold().monospacedDigit())
                }
                .foregroundStyle(.green)
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
