import SwiftUI
import WordClipKit
#if os(macOS)
import ServiceManagement
import KeyboardShortcuts
#endif

/// 全局 App 运行状态，注入到所有 View 的 environment。
@MainActor
final class AppState: ObservableObject {

    // MARK: - 词典（由 App 层初始化后注入，供收词和修复释义共用）
    /// 当前生效的词库（内置 + 用户导入的组合）。
    var dictionary: (any DictionaryProvider)?
    /// 内置词库单独留存，用于导入/删除后重建组合词库。
    var builtinDictionary: (any DictionaryProvider)?

    // MARK: - 收词服务（由 App 层初始化后注入，供手动添加/粘贴调用）
    var collector: WordCollector?

    /// 词典增删后重建组合词库，并同步给 collector（取词/修复共用）。
    /// 触发 objectWillChange 让依赖词典的视图刷新。
    func rebuildDictionary() {
        guard let builtin = builtinDictionary else { return }
        let combined = DictionaryStore.shared.buildProvider(builtin: builtin)
        dictionary = combined
        collector?.dictionary = combined
        objectWillChange.send()
    }

    /// 手动添加单词（手输/粘贴）。返回反馈文案供 UI 展示。
    func collect(word: String) async -> String? {
        guard let collector else { return nil }
        let outcome = await collector.collect(word: word)
        let msg = WordClipApp.feedback(for: outcome)
        flashCollectMessage(msg)
        return msg
    }

    // MARK: - 收录反馈
    /// 最近一次收录的提示文案，UI（状态栏/Toast）可观察展示。
    @Published var lastCollectMessage: String?
    /// 是否需要引导用户授予辅助功能权限。
    @Published var needsAccessibilityPrompt: Bool = false

    /// 展示一条短暂的收录反馈，几秒后自动清除。
    func flashCollectMessage(_ message: String) {
        lastCollectMessage = message
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if lastCollectMessage == message {
                lastCollectMessage = nil
            }
        }
    }

    // MARK: - 复习提醒（每日本地通知，跨平台）

    @Published var reviewReminderEnabled: Bool = UserDefaults.standard.bool(forKey: "reviewReminderEnabled") {
        didSet {
            UserDefaults.standard.set(reviewReminderEnabled, forKey: "reviewReminderEnabled")
            applyReviewReminder()
        }
    }
    /// 提醒时间（仅取 hour/minute），默认 20:00。
    @Published var reviewReminderTime: Date = {
        let saved = UserDefaults.standard.double(forKey: "reviewReminderTime")
        if saved > 0 { return Date(timeIntervalSince1970: saved) }
        return Calendar.current.date(from: DateComponents(hour: 20, minute: 0)) ?? Date()
    }() {
        didSet {
            UserDefaults.standard.set(reviewReminderTime.timeIntervalSince1970, forKey: "reviewReminderTime")
            applyReviewReminder()
        }
    }

    /// 按当前开关与时间应用提醒调度。
    func applyReviewReminder() {
        if reviewReminderEnabled {
            let c = Calendar.current.dateComponents([.hour, .minute], from: reviewReminderTime)
            NotificationService.scheduleReviewReminder(hour: c.hour ?? 20, minute: c.minute ?? 0)
        } else {
            NotificationService.cancelReviewReminder()
        }
    }

    #if os(macOS)

    // MARK: - 取词开关（仅 macOS）
    /// true = 全局快捷键激活，可取词
    @Published var captureEnabled: Bool = true {
        didSet { refreshHotkeyRegistration() }
    }

    // MARK: - 开机自启（仅 macOS）
    @Published var launchAtLogin: Bool = false {
        didSet {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                launchAtLogin = !launchAtLogin
            }
        }
    }

    // MARK: - 收词回调（由 App 层注入真实逻辑）
    var onCollect: (() -> Void)?

    init() {
        // 读取 SMAppService 真实状态初始化，避免与系统状态不同步
        launchAtLogin = SMAppService.mainApp.status == .enabled
        refreshHotkeyRegistration()
    }

    /// 检测辅助功能授权状态，未授权时显示横幅引导。
    func checkAccessibilityStatus() {
        needsAccessibilityPrompt = !SelectionReader.isTrusted
    }

    /// 用户手动关闭横幅（不影响实际授权状态，下次启动会重新检测）。
    func dismissAccessibilityPrompt() {
        needsAccessibilityPrompt = false
    }

    /// 根据当前 captureEnabled 状态注册/注销全局热键。
    /// 修改快捷键后也应调用，以确保监听绑定到最新的快捷键。
    func refreshHotkeyRegistration() {
        if captureEnabled {
            KeyboardShortcuts.onKeyUp(for: .collectWord) { [weak self] in
                self?.onCollect?()
            }
        } else {
            KeyboardShortcuts.disable(.collectWord)
        }
    }

    #else

    init() {}

    #endif
}
