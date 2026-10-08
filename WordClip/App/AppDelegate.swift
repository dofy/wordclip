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

    @MainActor static var openMainWindow: (() -> Void)? {
        didSet {
            if pendingMainWindowRequest, openMainWindow != nil {
                pendingMainWindowRequest = false
                showMainWindow()
            }
        }
    }
    @MainActor private static var pendingMainWindowRequest = false

    @MainActor static func showMainWindow() {
        if DockVisibility.shared.reopenWindow(identifier: AppState.mainWindowIdentifier) {
            return
        }
        DockVisibility.shared.showDockIcon()
        if let openMainWindow {
            openMainWindow()
            NSApp.activate(ignoringOtherApps: true)
        } else {
            pendingMainWindowRequest = true
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        MainActor.assumeIsolated { Self.showMainWindow() }
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    /// 抢先接管 GURL Apple Event。
    ///
    /// 仅靠 `application(_:open:)` 不够：SwiftUI 的 scene 系统也会收到同一个 URL 事件，
    /// 由于主/设置窗口都未“认领”该 scheme，SwiftUI 会临时新建一个空白窗口去处理再关掉，
    /// 表现为收词时窗口一闪。这里在 SwiftUI 装好 handler *之后* 再覆盖它，
    /// 使 URL 只走这条路径、不进入 scene 路由，从根上消除闪烁。
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 总在主线程调用，assumeIsolated 拿到 MainActor 隔离而不用 Task 推迟一拍。
        MainActor.assumeIsolated { DockVisibility.shared.install() }
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc private func handleGetURLEvent(_ event: NSAppleEventDescriptor,
                                         withReplyEvent reply: NSAppleEventDescriptor) {
        guard let string = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: string) else { return }
        route(url)
    }

    /// 兜底：某些投递路径仍会走 NSApplication 的 open urls。
    func application(_ application: NSApplication, open urls: [URL]) {
        urls.forEach(route)
    }

    /// 解析并分发 wordclip:// URL。
    private func route(_ url: URL) {
        guard url.scheme == "wordclip",
              let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return }
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
