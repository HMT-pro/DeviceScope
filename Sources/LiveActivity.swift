import Foundation
import ActivityKit

/// Starts / updates / ends the Dynamic Island Live Activity.
/// Failures are surfaced via `lastError` instead of being swallowed.
@MainActor
final class LiveActivityController {
    static let shared = LiveActivityController()

    private var activity: Activity<DeviceActivityAttributes>?
    private(set) var isRunning = false
    private(set) var lastError: String?

    /// Adopt an activity that is already running (e.g. after app relaunch).
    func syncFromSystem() {
        if let existing = Activity<DeviceActivityAttributes>.activities.first {
            activity = existing
            isRunning = true
        }
    }

    func start(deviceName: String, state: DeviceActivityAttributes.ContentState) {
        lastError = nil
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            lastError = "系统未允许实时活动：到「设置 → DeviceScope」打开「实时活动」，再回来点一次。"
            isRunning = false
            return
        }
        // End any stale activities from earlier sessions first.
        for a in Activity<DeviceActivityAttributes>.activities {
            Task { await a.end(nil, dismissalPolicy: .immediate) }
        }
        activity = nil
        do {
            activity = try Activity.request(
                attributes: DeviceActivityAttributes(deviceName: deviceName),
                content: ActivityContent(state: state, staleDate: nil)
            )
            isRunning = activity != nil
            if !isRunning {
                lastError = "开启失败：系统没有创建实时活动。"
            }
        } catch {
            lastError = "开启失败：\(error.localizedDescription)"
            isRunning = false
        }
    }

    func update(_ state: DeviceActivityAttributes.ContentState) {
        guard let activity else { return }
        Task {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    func stop() {
        for a in Activity<DeviceActivityAttributes>.activities {
            Task { await a.end(nil, dismissalPolicy: .immediate) }
        }
        activity = nil
        isRunning = false
        lastError = nil
    }
}
