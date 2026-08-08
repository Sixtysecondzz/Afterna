import Foundation
import ActivityKit

/// Shared attributes for the recording Live Activity (Dynamic Island / Lock Screen).
struct RecordingActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var startedAt: Date
        var title: String
        var isPaused: Bool
    }

    var sessionId: String
}
