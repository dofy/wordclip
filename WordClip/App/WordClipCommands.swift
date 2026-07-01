#if os(macOS)
import SwiftUI

// Notification.Name 定义见 ContentView.swift（跨平台共用）。

/// macOS 菜单栏命令
struct WordClipCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        // ⌘, 打开设置窗口
        CommandGroup(replacing: .appSettings) {
            Button(String(localized: "menu.settings", defaultValue: "设置…")) {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut(",", modifiers: .command)
        }

        // 帮助 → 键盘快捷键（⌘/）
        CommandGroup(replacing: .help) {
            Button(String(localized: "shortcuts.title", defaultValue: "键盘快捷键")) {
                NotificationCenter.default.post(name: .showShortcutCheatSheet, object: nil)
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut("/", modifiers: .command)
        }
    }
}
#endif
