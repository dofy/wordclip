#if os(macOS)
import AppKit
import SwiftUI
import UserNotifications

extension Notification.Name {
    /// 通过 URL scheme 请求收录单词（object 为 word 字符串）。
    static let collectWordFromURL = Notification.Name("collectWordFromURL")
}

/// AppDelegate：窗口生命周期 + URL scheme 路由。
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

    /// 在 AppDelegate 层处理 URL scheme：SwiftUI 的 onOpenURL + handlesExternalEvents
    /// 会把非 "main" 的 URL 误路由到设置窗口，这里统一拦截，保证 collect 可靠。
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard url.scheme == "wordclip",
                  let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
            else { continue }
            switch comps.host {
            case "collect":
                if let word = comps.queryItems?.first(where: { $0.name == "word" })?.value,
                   !word.isEmpty {
                    NotificationCenter.default.post(name: .collectWordFromURL, object: word)
                }
            default:
                break
            }
        }
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
