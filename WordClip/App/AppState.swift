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

    /// 免费用户触发 OCR 取词时，请求呈现付费墙（由 ContentView 观察并弹 sheet）。
    @Published var showingOCRPaywall: Bool = false

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
    /// OCR 取词回调（由 App 层注入；内部自带 Pro 闸门）。
    var onCollectOCR: (() -> Void)?

    /// 请求呈现付费墙：先把 app 与主窗口前置（OCR 快捷键可能在后台触发），再置标志。
    func presentPaywall() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.identifier?.rawValue == "main" {
            window.makeKeyAndOrderFront(nil)
        }
        showingOCRPaywall = true
    }

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

    #if os(macOS)
    /// 订阅授权状态变化，让横幅在用户授权后立刻消失。
    ///
    /// 只在 onAppear 检测一次是不够的：用户是在 app 启动之后才去系统设置里打开
    /// 开关的，回到 app 时横幅仍然挂着，看起来像没授权成功。
    /// - `com.apple.accessibility.api` 是系统在辅助功能授权变动时发出的分布式
    ///   通知，不需要轮询；它的投递有轻微延迟，故延后一拍再读。
    /// - 再补一个 app 重新激活时的复查，兜住通知没收到的情况。
    func observeAccessibilityChanges() {
        guard accessibilityObservers.isEmpty else { return }

        let recheck: (Notification) -> Void = { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.checkAccessibilityStatus()
            }
        }

        accessibilityObservers.append(
            DistributedNotificationCenter.default().addObserver(
                forName: NSNotification.Name("com.apple.accessibility.api"),
                object: nil,
                queue: .main,
                using: recheck
            )
        )
        accessibilityObservers.append(
            NotificationCenter.default.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main,
                using: recheck
            )
        )
    }

    /// 观察者句柄，仅用于避免重复注册。
    ///
    /// 不做反注册：AppState 注入在 App 根节点，生命周期等于进程，观察者本就该
    /// 活到退出。写 deinit 反而过不了 Swift 6 的并发检查——deinit 是 nonisolated，
    /// 不能访问 @MainActor 隔离的非 Sendable 属性。
    private var accessibilityObservers: [NSObjectProtocol] = []
    #endif

    /// 热键回调是否已注册（onKeyUp 只需注册一次，否则会叠加重复触发）。
    private var hotkeyHandlerRegistered = false
    /// OCR 热键回调是否已注册。
    private var ocrHotkeyHandlerRegistered = false

    /// 根据当前 captureEnabled 状态启用/停用全局热键。
    /// 修改快捷键后也应调用。
    func refreshHotkeyRegistration() {
        // 回调只注册一次；开关状态用 enable/disable 切换。
        // 之前每次开启都重复 onKeyUp，且 disable 后未 enable，
        // 导致「关闭再打开」后快捷键失效。
        if !hotkeyHandlerRegistered {
            KeyboardShortcuts.onKeyUp(for: .collectWord) { [weak self] in
                self?.onCollect?()
            }
            hotkeyHandlerRegistered = true
        }
        if captureEnabled {
            KeyboardShortcuts.enable(.collectWord)
        } else {
            KeyboardShortcuts.disable(.collectWord)
        }

        // OCR 取词：独立于 captureEnabled（那个开关只管选中取词），始终启用。
        // Pro 闸门在回调内部判断（免费用户按下会弹付费墙而非截屏）。
        if !ocrHotkeyHandlerRegistered {
            KeyboardShortcuts.onKeyUp(for: .collectWordOCR) { [weak self] in
                self?.onCollectOCR?()
            }
            ocrHotkeyHandlerRegistered = true
        }
        KeyboardShortcuts.enable(.collectWordOCR)
    }

    #else

    init() {}

    #endif
}
