import Foundation
import UserNotifications

@MainActor
enum LocalNotificationService {
    static func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    static func scheduleMeetingSoon(title: String, at date: Date, meetingId: String) {
        let content = UNMutableNotificationContent()
        content.title = "Meeting starting soon"
        content.body = "\(title) — open Afterna to capture?"
        content.sound = .default
        content.userInfo = ["type": "meeting_soon", "meetingId": meetingId]

        let triggerDate = date.addingTimeInterval(-2 * 60)
        guard triggerDate > Date() else { return }
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let req = UNNotificationRequest(identifier: "meeting-\(meetingId)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }

    static func notifyNotesReady(title: String, conversationId: UUID) {
        let content = UNMutableNotificationContent()
        content.title = "Notes ready"
        content.body = "Key points for “\(title)” are ready."
        content.sound = .default
        content.userInfo = ["type": "notes_ready", "conversationId": conversationId.uuidString]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let req = UNNotificationRequest(
            identifier: "notes-\(conversationId.uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(req)
    }
}
