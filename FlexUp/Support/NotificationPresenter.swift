import Foundation
import UserNotifications

/// iOS suppresses notification banners and sounds while the app is open.
/// An alarm should still fire in that case, so FlexUp opts into presenting
/// them itself.
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationPresenter()

    func register() {
        UNUserNotificationCenter.current().delegate = self
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }
}
