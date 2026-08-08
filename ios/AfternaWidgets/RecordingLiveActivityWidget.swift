import ActivityKit
import SwiftUI
import WidgetKit

struct RecordingLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordingActivityAttributes.self) { context in
            HStack(spacing: 12) {
                Image(systemName: "mic.circle.fill")
                    .foregroundStyle(Color(red: 0.18, green: 0.44, blue: 0.41))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Afterna recording")
                        .font(.caption.weight(.semibold))
                    Text(context.state.title)
                        .font(.subheadline)
                        .lineLimit(1)
                    Text(context.state.startedAt, style: .timer)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()
            .activityBackgroundTint(Color(red: 0.96, green: 0.95, blue: 0.93))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "mic.fill")
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.title)
                        .font(.caption)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.startedAt, style: .timer)
                        .font(.caption.monospacedDigit())
                }
            } compactLeading: {
                Image(systemName: "mic.fill")
            } compactTrailing: {
                Text(context.state.startedAt, style: .timer)
                    .font(.caption2.monospacedDigit())
            } minimal: {
                Image(systemName: "mic.fill")
            }
        }
    }
}
