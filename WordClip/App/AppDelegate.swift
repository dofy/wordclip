#if os(macOS)
import AppKit
import SwiftUI
import UserNotifications

/// AppDelegate：只负责窗口生命周期管理。
/// 通知 delegate 由 NotificationDelegate 单例负责，避免被 SwiftUI 场景覆盖。
final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows {
            for window in sender.windows { window.makeKeyAndOrderFront(nil) }
        }
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}

// MARK: - NotificationDelegate

/// 独立的通知 delegate 单例，生命周期与 app 绑定，不受 SwiftUI scene 影响。
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {

    static let shared = NotificationDelegate()
    private override init() {}

    /// app 在前台时系统默认会压制通知；返回 .banner 让它照常展示。
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner])
    }
}
#endif
