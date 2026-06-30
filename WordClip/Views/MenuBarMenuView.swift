#if os(macOS)
import SwiftUI

/// 状态栏菜单内容
struct MenuBarMenuView: View {
    @EnvironmentObject private var appState: AppState
    /// 用于打开/激活主窗口
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        // 取词开关
        Button {
            appState.captureEnabled.toggle()
        } label: {
            Label(
                appState.captureEnabled
                    ? String(localized: "menubar.capture.disable", defaultValue: "停用取词")
                    : String(localized: "menubar.capture.enable", defaultValue: "启用取词"),
                systemImage: appState.captureEnabled ? "scissors.badge.ellipsis" : "scissors"
            )
        }
        .keyboardShortcut("e", modifiers: [.command])

        Divider()

        // 打开主窗口
        Button(String(localized: "menubar.open", defaultValue: "打开 WordClip")) {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut("o", modifiers: [.command])

        // 打开设置
        Button(String(localized: "menubar.settings", defaultValue: "设置…")) {
            openWindow(id: "settings")
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",", modifiers: .command)

        Divider()

        // 退出
        Button(String(localized: "menubar.quit", defaultValue: "退出")) {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: [.command])
    }
}
#endif
