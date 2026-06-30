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
    var dictionary: (any DictionaryProvider)?

    // MARK: - 收词服务（由 App 层初始化后注入，供手动添加/粘贴调用）
    var collector: WordCollector?

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
