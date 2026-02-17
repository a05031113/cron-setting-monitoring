import UserNotifications

final class NotificationManager: Sendable {
    static let shared = NotificationManager()

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func sendFailureNotification(jobName: String, exitCode: Int) {
        let content = UNMutableNotificationContent()
        content.title = "CronMonitor: Job Failed"
        content.body = "\(jobName) exited with code \(exitCode)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
