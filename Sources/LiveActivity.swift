import Foundation
import ActivityKit

/// Starts / updates / ends the Dynamic Island Live Activity.
@MainActor
final class LiveActivityController {
    static let shared = LiveActivityController()

    private var activity: Activity<DeviceActivityAttributes>?
    private(set) var isRunning = false

    func start(deviceName: String, state: DeviceActivityAttributes.ContentState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            isRunning = false
            return
        }
        stop()
        do {
            activity = try Activity.request(
                attributes: DeviceActivityAttributes(deviceName: deviceName),
                content: ActivityContent(state: state, staleDate: nil)
            )
            isRunning = true
        } catch {
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
        guard let activity else {
            isRunning = false
            return
        }
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        self.activity = nil
        isRunning = false
    }
}
