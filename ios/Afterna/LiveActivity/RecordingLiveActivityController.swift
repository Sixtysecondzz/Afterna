import ActivityKit
import Foundation

@MainActor
enum RecordingLiveActivityController {
    private static var current: Activity<RecordingActivityAttributes>?

    static func start(sessionId: UUID, title: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // End any stale activity first.
        end()
        let attributes = RecordingActivityAttributes(sessionId: sessionId.uuidString)
        let state = RecordingActivityAttributes.ContentState(
            startedAt: Date(),
            title: title,
            isPaused: false
        )
        do {
            current = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            print("[LiveActivity] start failed: \(error.localizedDescription)")
        }
    }

    static func end() {
        guard let activity = current else { return }
        let finalState = RecordingActivityAttributes.ContentState(
            startedAt: activity.content.state.startedAt,
            title: activity.content.state.title,
            isPaused: false
        )
        Task {
            await activity.end(.init(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
        }
        current = nil
    }
}
