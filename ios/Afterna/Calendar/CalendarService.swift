import EventKit
import Foundation
import Observation

/// Lightweight EventKit-backed meeting for Capture UI.
struct CalendarMeeting: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let attendeeNames: [String]

    var isHappeningNow: Bool {
        let now = Date()
        return startDate <= now && endDate > now
    }

    /// Starts within the next 10 minutes (and has not already begun).
    var startsSoon: Bool {
        let seconds = startDate.timeIntervalSinceNow
        return seconds > 0 && seconds <= 10 * 60
    }

    var timeLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        if isHappeningNow {
            return "Now · until \(formatter.string(from: endDate))"
        }
        return formatter.string(from: startDate)
    }
}

/// Reads upcoming calendar events for Capture auto-title / chip picker.
@Observable
@MainActor
final class CalendarService {
    private let store = EKEventStore()

    /// Horizon for the chip picker (hours from now).
    private let lookAheadHours: Double = 6
    /// Include meetings that started this many minutes ago but are still ongoing.
    private let lookBackMinutes: Double = 30

    private(set) var authorizationStatus: EKAuthorizationStatus = .notDetermined
    private(set) var upcomingMeetings: [CalendarMeeting] = []
    private(set) var selectedMeeting: CalendarMeeting?
    /// In-app “starting soon” prompt target; nil when dismissed or none.
    private(set) var startingSoonPrompt: CalendarMeeting?
    private var dismissedStartingSoonIds: Set<String> = []

    var hasAccess: Bool {
        switch authorizationStatus {
        case .fullAccess, .authorized:
            return true
        default:
            return false
        }
    }

    /// Permission denied / restricted → hide banner silently.
    var shouldShowBanner: Bool {
        hasAccess && !upcomingMeetings.isEmpty
    }

    /// Title to use when archiving / drafting, if the user picked a meeting.
    var selectedTitle: String? {
        guard let title = selectedMeeting?.title.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty else { return nil }
        return title
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    /// Request calendar access once, then load upcoming meetings. Safe to call repeatedly.
    func prepareForCapture() async {
        refreshAuthorizationStatus()
        switch authorizationStatus {
        case .fullAccess, .authorized:
            refreshUpcoming()
        case .notDetermined:
            do {
                let granted = try await store.requestFullAccessToEvents()
                refreshAuthorizationStatus()
                if granted {
                    refreshUpcoming()
                } else {
                    clearMeetings()
                }
            } catch {
                clearMeetings()
            }
        default:
            clearMeetings()
        }
    }

    func select(_ meeting: CalendarMeeting?) {
        selectedMeeting = meeting
        if let meeting, meeting.startsSoon || meeting.isHappeningNow {
            dismissedStartingSoonIds.insert(meeting.id)
            if startingSoonPrompt?.id == meeting.id {
                startingSoonPrompt = nil
            }
        }
    }

    func dismissStartingSoonPrompt() {
        if let id = startingSoonPrompt?.id {
            dismissedStartingSoonIds.insert(id)
        }
        startingSoonPrompt = nil
    }

    func refreshUpcoming() {
        refreshAuthorizationStatus()
        guard hasAccess else {
            clearMeetings()
            return
        }

        let now = Date()
        let start = now.addingTimeInterval(-lookBackMinutes * 60)
        let end = now.addingTimeInterval(lookAheadHours * 3600)
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = store.events(matching: predicate)
            .filter { !$0.isAllDay }
            .filter { $0.endDate > now }
            .sorted { $0.startDate < $1.startDate }

        let meetings = events.prefix(10).compactMap { event -> CalendarMeeting? in
            guard let eventId = event.eventIdentifier else { return nil }
            let rawTitle = event.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let title = rawTitle.isEmpty ? "Untitled meeting" : rawTitle
            let attendees = (event.attendees ?? [])
                .compactMap { $0.name?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            return CalendarMeeting(
                id: eventId,
                title: title,
                startDate: event.startDate,
                endDate: event.endDate,
                attendeeNames: Array(attendees.prefix(12))
            )
        }

        upcomingMeetings = Array(meetings)
        reconcileSelection()
        updateStartingSoonPrompt()
        scheduleMeetingNotifications()
    }

    private func scheduleMeetingNotifications() {
        Task {
            await LocalNotificationService.requestAuthorizationIfNeeded()
            for meeting in upcomingMeetings where meeting.startsSoon || meeting.startDate > Date() {
                LocalNotificationService.scheduleMeetingSoon(
                    title: meeting.title,
                    at: meeting.startDate,
                    meetingId: meeting.id
                )
            }
        }
    }

    private func reconcileSelection() {
        if let selected = selectedMeeting,
           upcomingMeetings.contains(where: { $0.id == selected.id }) {
            // Refresh stale copy (times may have changed).
            selectedMeeting = upcomingMeetings.first(where: { $0.id == selected.id })
            return
        }
        selectedMeeting =
            upcomingMeetings.first(where: \.isHappeningNow)
            ?? upcomingMeetings.first(where: \.startsSoon)
            ?? upcomingMeetings.first
    }

    private func updateStartingSoonPrompt() {
        startingSoonPrompt = upcomingMeetings.first { meeting in
            meeting.startsSoon && !dismissedStartingSoonIds.contains(meeting.id)
        }
    }

    private func clearMeetings() {
        upcomingMeetings = []
        selectedMeeting = nil
        startingSoonPrompt = nil
    }
}
