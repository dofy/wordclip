import UserNotifications

/// 封装本地通知的发送逻辑。
/// 权限申请由 AppDelegate.applicationDidFinishLaunching 负责。
@MainActor
enum NotificationService {

    /// 发送收词结果通知。
    /// - Parameters:
    ///   - word: 收录的单词
    ///   - definition: 释义首行，nil 则显示"暂无释义"
    ///   - found: 词典是否命中
    static func sendCollectNotification(word: String, definition: String?, found: Bool) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.collect.title",
                               defaultValue: "已收录：\(word)")
        if found, let def = definition?.components(separatedBy: "\n").first, !def.isEmpty {
            content.body = def
        } else if !found {
            content.body = String(localized: "notification.collect.nodef",
                                  defaultValue: "词典未收录该词，释义留空")
        }
        content.sound = .none  // 收词是高频操作，静音避免打扰

        let request = UNNotificationRequest(
            identifier: "collect-\(word)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil  // 立即发送
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                NSLog("[WordClip] 发送收词通知失败: \(error)")
            }
        }
    }

    /// 发送错误提示通知（未授权辅助功能等）。
    static func sendErrorNotification(message: String) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.error.title",
                               defaultValue: "WordClip")
        content.body = message
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "error-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - 复习提醒（每日重复）

    private static let reviewReminderID = "review-reminder-daily"

    /// 调度每日复习提醒。
    /// - Parameters:
    ///   - hour: 提醒小时（0–23）
    ///   - minute: 提醒分钟
    static func scheduleReviewReminder(hour: Int, minute: Int) {
        Task {
            let center = UNUserNotificationCenter.current()
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            guard granted else { return }

            let content = UNMutableNotificationContent()
            content.title = String(localized: "reminder.title", defaultValue: "该复习单词啦")
            content.body = String(localized: "reminder.body",
                                  defaultValue: "打开 WordClip 复习今天到期的单词")
            content.sound = .default

            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

            let request = UNNotificationRequest(
                identifier: reviewReminderID, content: content, trigger: trigger
            )
            center.removePendingNotificationRequests(withIdentifiers: [reviewReminderID])
            try? await center.add(request)
        }
    }

    /// 取消每日复习提醒。
    static func cancelReviewReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [reviewReminderID])
    }
}

