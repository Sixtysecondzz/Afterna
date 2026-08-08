import SwiftUI

/// Compact chip picker of upcoming calendar meetings for Capture.
struct UpcomingMeetingBanner: View {
    var calendar: CalendarService
    @State private var briefMeeting: CalendarMeeting?

    var body: some View {
        if calendar.shouldShowBanner {
            VStack(alignment: .leading, spacing: DesignTokens.spaceS) {
                if let prompt = calendar.startingSoonPrompt {
                    startingSoonRow(prompt)
                }

                HStack {
                    Text("Link to meeting")
                        .font(DesignTokens.captionFont)
                        .foregroundStyle(DesignTokens.textSecondary)
                    Spacer()
                    if let selected = calendar.selectedMeeting {
                        Button("Brief") { briefMeeting = selected }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DesignTokens.accent)
                            .accessibilityLabel("Open meeting brief")
                    }
                }
                .padding(.horizontal, DesignTokens.spaceXS)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignTokens.spaceS) {
                        ForEach(calendar.upcomingMeetings) { meeting in
                            meetingChip(meeting)
                        }
                        clearChip
                    }
                    .padding(.horizontal, DesignTokens.spaceXS)
                }
            }
            .accessibilityElement(children: .contain)
            .sheet(item: $briefMeeting) { meeting in
                MeetingBriefSheet(meetingTitle: meeting.title, attendeeNames: meeting.attendeeNames)
            }
        }
    }

    private func startingSoonRow(_ meeting: CalendarMeeting) -> some View {
        HStack(spacing: DesignTokens.spaceS) {
            Image(systemName: "bell.fill")
                .font(.caption)
                .foregroundStyle(DesignTokens.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("Starting soon")
                    .font(DesignTokens.captionFont)
                    .foregroundStyle(DesignTokens.accent)
                Text(meeting.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(DesignTokens.ink)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button("Use") {
                calendar.select(meeting)
                Haptics.impact(.light)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(DesignTokens.accent))

            Button {
                calendar.dismissStartingSoonPrompt()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.textSecondary)
                    .padding(6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(.horizontal, DesignTokens.spaceM)
        .padding(.vertical, DesignTokens.spaceS)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.radius, style: .continuous)
                .fill(DesignTokens.mist)
        )
        .padding(.horizontal, DesignTokens.spaceXS)
    }

    private func meetingChip(_ meeting: CalendarMeeting) -> some View {
        let selected = calendar.selectedMeeting?.id == meeting.id
        return Button {
            calendar.select(meeting)
            Haptics.impact(.light)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(meeting.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(meeting.timeLabel)
                    .font(.caption2)
                    .opacity(0.85)
            }
            .foregroundStyle(selected ? Color.white : DesignTokens.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(selected ? DesignTokens.accent : DesignTokens.mist)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(meeting.title), \(meeting.timeLabel)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var clearChip: some View {
        let cleared = calendar.selectedMeeting == nil
        return Button {
            calendar.select(nil)
            Haptics.impact(.light)
        } label: {
            Text("None")
                .font(.caption.weight(.semibold))
                .foregroundStyle(cleared ? Color.white : DesignTokens.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(cleared ? DesignTokens.accent.opacity(0.75) : DesignTokens.mist.opacity(0.7))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("No meeting")
    }
}
