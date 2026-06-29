import SwiftUI
import ServiceManagement
import KeyboardShortcuts

/// 全局 App 运行状态，注入到所有 View 的 environment。
@MainActor
final class AppState: ObservableObject {

    // MARK: - 取词开关
    /// true = 全局快捷键激活，可取词
    @Published var captureEnabled: Bool = true {
        didSet { updateHotkeyRegistration() }
    }

    // MARK: - 开机自启
    @Published var launchAtLogin: Bool {
        didSet {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // 注册失败回滚 UI 状态
                launchAtLogin = !launchAtLogin
            }
        }
    }

    // MARK: - 收词回调（M2 接入真实逻辑）
    var onCollect: (() -> Void)?

    init() {
        // 读取 SMAppService 真实状态初始化，避免与系统状态不同步
        launchAtLogin = SMAppService.mainApp.status == .enabled
        updateHotkeyRegistration()
    }

    // MARK: - Private

    private func updateHotkeyRegistration() {
        if captureEnabled {
            KeyboardShortcuts.onKeyUp(for: .collectWord) { [weak self] in
                self?.onCollect?()
            }
        } else {
            KeyboardShortcuts.disable(.collectWord)
        }
    }
}
