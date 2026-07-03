import Foundation
import UserNotifications
import UIKit
import CoreLocation

@MainActor
public final class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    public static let shared = NotificationService()
    @Published public private(set) var isAuthorized = false
    private let center = UNUserNotificationCenter.current()

    private override init() {
        super.init()
        center.delegate = self
        setupCategories()
        checkPermissionStatus()
    }

    public func checkPermissionStatus() {
        Task { isAuthorized = await center.notificationSettings().authorizationStatus == .authorized }
    }

    public func requestPermission(completion: @escaping (Bool) -> Void = { _ in }) {
        Task {
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            isAuthorized = granted
            completion(granted)
        }
    }

    public func setupCategories() {
        let done = UNNotificationAction(identifier: "DONE_ACTION", title: "Done", options: [])
        let snooze = UNNotificationAction(identifier: "SNOOZE_ACTION", title: "Later", options: [])
        let navigate = UNNotificationAction(identifier: "NAVIGATE_ACTION", title: "Navigate", options: [.foreground])
        let wait = UNNotificationAction(identifier: "WAIT_ORIGINAL_ACTION", title: "Wait for original place", options: [])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: "REMINDER_CATEGORY", actions: [done, snooze, navigate], intentIdentifiers: []),
            UNNotificationCategory(identifier: "ALTERNATIVE_REMINDER_CATEGORY", actions: [done, wait, snooze, navigate], intentIdentifiers: [])
        ])
    }

    public func triggerNotification(for reminder: Reminder, alternativePlaceName: String? = nil,
                                    alternativeCoordinate: CLLocationCoordinate2D? = nil) {
        let content = UNMutableNotificationContent()
        if let alternativePlaceName {
            content.title = "You’re close to \(alternativePlaceName)"
            content.body = "You wanted to: \(reminder.title)"
            content.categoryIdentifier = "ALTERNATIVE_REMINDER_CATEGORY"
        } else {
            content.title = reminder.placeName
            content.body = reminder.title
            content.categoryIdentifier = "REMINDER_CATEGORY"
        }
        content.sound = .default
        content.userInfo = [
            "REMINDER_ID": reminder.id.uuidString,
            "LATITUDE": alternativeCoordinate?.latitude ?? reminder.latitude,
            "LONGITUDE": alternativeCoordinate?.longitude ?? reminder.longitude
        ]
        let delay = SettingsStore.shared.isQuiet() ? secondsUntilQuietHoursEnd() : 1
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false)
        center.add(UNNotificationRequest(identifier: "\(reminder.id)-\(Date().timeIntervalSince1970)", content: content, trigger: trigger))
    }

    nonisolated public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    nonisolated public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void) {
        Task { @MainActor in
            defer { completionHandler() }
            let info = response.notification.request.content.userInfo
            guard let raw = info["REMINDER_ID"] as? String, let id = UUID(uuidString: raw),
                  let reminder = ReminderStore.shared.fetchReminder(withId: id) else { return }
            switch response.actionIdentifier {
            case "DONE_ACTION":
                reminder.markDone()
                GeofenceManager.shared.stop(reminder: reminder)
            case "WAIT_ORIGINAL_ACTION":
                reminder.alternativesDisabled = true
            case "SNOOZE_ACTION":
                reminder.snoozedUntil = Date().addingTimeInterval(30 * 60)
                scheduleSnooze(reminder)
            case "NAVIGATE_ACTION", UNNotificationDefaultActionIdentifier:
                let lat = info["LATITUDE"] as? Double ?? reminder.latitude
                let lon = info["LONGITUDE"] as? Double ?? reminder.longitude
                if let url = URL(string: "http://maps.apple.com/?daddr=\(lat),\(lon)&dirflg=d") { await UIApplication.shared.open(url) }
            default: break
            }
            ReminderStore.shared.save()
            await GeofenceManager.shared.refresh(near: LocationService.shared.currentLocation)
        }
    }

    private func scheduleSnooze(_ reminder: Reminder) {
        let content = UNMutableNotificationContent()
        content.title = reminder.placeName
        content.body = reminder.title
        content.sound = .default
        content.categoryIdentifier = "REMINDER_CATEGORY"
        content.userInfo = ["REMINDER_ID": reminder.id.uuidString, "LATITUDE": reminder.latitude, "LONGITUDE": reminder.longitude]
        center.add(UNNotificationRequest(identifier: "\(reminder.id)-snooze", content: content,
                                         trigger: UNTimeIntervalNotificationTrigger(timeInterval: 30 * 60, repeats: false)))
    }

    private func secondsUntilQuietHoursEnd() -> TimeInterval {
        let settings = SettingsStore.shared
        let now = Date()
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        let todayEnd = calendar.date(byAdding: .minute, value: settings.quietHoursEndMinutes, to: start) ?? now
        let end = todayEnd > now ? todayEnd : calendar.date(byAdding: .day, value: 1, to: todayEnd) ?? now
        return end.timeIntervalSince(now)
    }
}
