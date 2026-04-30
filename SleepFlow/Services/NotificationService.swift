import Foundation
import UserNotifications

enum NotificationService {
    static let alarmIdentifier = "sleepflow.alarm"

    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func scheduleAlarm(hour: Int, minute: Int) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [alarmIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "Buen día"
        content.body = "Hora de despertar."
        content.sound = .default

        var date = DateComponents()
        date.hour = hour
        date.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: false)
        let request = UNNotificationRequest(identifier: alarmIdentifier, content: content, trigger: trigger)
        try? await center.add(request)
    }

    static func cancelAlarm() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [alarmIdentifier])
    }
}
